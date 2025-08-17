// lib/src/widgets/scene/host.dart

import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// layers
import 'layers/wires_layer.dart' show WiresLayer;
import 'layers/nodes_layer.dart' show NodesLayer;
import 'layers/viewer_layer.dart' show ViewerLayer;
import 'layers/preview_layer.dart' show PreviewLayer;
import 'layers/selection_layer.dart' show SelectionLayer;

// utils
import 'context_menu_handler.dart' show ContextMenuHandler;
import '../core/graph_controller.dart' show GraphController;

// events
import '../core/graph_events.dart'
    show
        ActiveBlueprintChanged,
        BlueprintOpened,
        BlueprintClosed,
        BlueprintRenamed,
        TabGraphChanged,
        TabGraphCleared;

import '../painter/grid_painter.dart' 
    show 
        GridPainter, 
        GridPainterCache;
import '../providers/graph/graph_state_provider.dart'
    show 
        GraphStateByTabNotifier, 
        graphProvider;
import '../providers/ui/canvas_providers.dart'
    show
        activeCanvasTickProvider,
        connectionCanvasKeyProvider,
        canvasScaleProvider;
import '../providers/connection/connection_providers.dart'
    show 
        connectionStartPortProvider, 
        connectionDragPosProvider;
import '../providers/ui/interaction_providers.dart' show nodeDraggingProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../providers/ui/viewport_provider.dart' show viewportProvider;

// ---- Parts (shared imports live in this file) -------------------------------
part 'scene/canvas_scene.dart';
part 'scene/grid_paint_proxy.dart';
part 'scene/virtualized_canvas.dart';

/// Host: entry widget that manages tabs (blueprints) and renders the active
/// CanvasScene. Replaces the old SceneBuilder+TabHost pair.
class Host extends ConsumerStatefulWidget {
  const Host({super.key});

  @override
  ConsumerState<Host> createState() => _HostState();
}

class _HostState extends ConsumerState<Host> {
  late final GraphController _graph;
  late final List<StreamSubscription> _subs;

  /// Per-tab layout-dirty flag (set when graph changed while tab was inactive).
  final Map<String, bool> _layoutDirty = {};

  /// Optional per-tab activation “tick”.
  final Map<String, int> _ticks = {};

  /// Persist a dedicated ProviderContainer per tab so **tab switches do not
  /// recreate ProviderScopes**.
  final Map<String, ProviderContainer> _containers = {};

  /// Explicit per-tab repaint tickers used to force one paint on activation
  /// so ProbePaintOnce always runs.
  final Map<String, ValueNotifier<int>> _repaints = {};

  ProviderContainer _createContainer(String tabId) {
    final sw = Stopwatch()..start();
    final container = ProviderContainer(
      overrides: [
        // Scope the graph to this tab only.
        graphProvider.overrideWith(
          (ref) => GraphStateByTabNotifier(_graph, tabId),
        ),
      ],
    );
    _containers[tabId] = container;
    sw.stop();
    dev.log(
      '[perf] Host._createContainer($tabId) took ${sw.elapsedMicroseconds / 1000.0} ms',
      name: 'badbadnode.perf',
    );
    return container;
  }

  ProviderContainer _ensureContainer(String tabId) =>
      _containers[tabId] ?? _createContainer(tabId);

  ValueNotifier<int> _ensureRepaint(String tabId) =>
      _repaints[tabId] ??= ValueNotifier<int>(0);

  void _disposeContainer(String tabId) {
    final c = _containers.remove(tabId);
    c?.dispose();
  }

  void _disposeRepaint(String tabId) {
    final n = _repaints.remove(tabId);
    n?.dispose();
  }

  void _bumpTick(String id) {
    final t = (_ticks[id] ?? 0) + 1;
    _ticks[id] = t;
    final c = _containers[id];
    if (c != null) {
      c.read(activeCanvasTickProvider.notifier).state = t;
    }
  }

  @override
  void initState() {
    super.initState();
    // NOTE: Keeping parity with previous TabHost behavior (direct instance).
    _graph = GraphController();

    // Seed first tab’s container + state
    final active = _graph.activeBlueprintId;
    _ticks[active] = 0;
    _layoutDirty[active] = false;
    _ensureContainer(active);
    _ensureRepaint(active);

    _subs = [
      _graph.on<ActiveBlueprintChanged>().listen((e) {
        final sw = Stopwatch()..start();

        // Ensure a repaint for ProbePaintOnce on the activated tab.
        _ensureRepaint(e.id).value++;

        // If the tab’s layout changed while inactive, poke it once.
        if (_layoutDirty[e.id] == true) {
          _bumpTick(e.id);
          _layoutDirty[e.id] = false;
        }

        if (mounted) setState(() {});
        sw.stop();
        dev.log(
          '[perf] Host.onActiveBlueprintChanged listener: ${sw.elapsedMilliseconds} ms',
          name: 'badbadnode.perf',
        );
      }),
      _graph.on<BlueprintOpened>().listen((e) {
        _ticks.putIfAbsent(e.id, () => 0);
        _layoutDirty.putIfAbsent(e.id, () => false);
        _ensureContainer(e.id);
        _ensureRepaint(e.id);
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintClosed>().listen((e) {
        _ticks.remove(e.id);
        _layoutDirty.remove(e.id);
        GridPainterCache.evict(e.id); // free per-tab grid picture cache
        _disposeContainer(e.id);
        _disposeRepaint(e.id);
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintRenamed>().listen((_) {
        if (mounted) setState(() {});
      }),
      _graph.on<TabGraphChanged>().listen((e) {
        if (e.id != _graph.activeBlueprintId) {
          _layoutDirty[e.id] = true;
        }
      }),
      _graph.on<TabGraphCleared>().listen((e) {
        if (e.id != _graph.activeBlueprintId) {
          _layoutDirty[e.id] = true;
        }
      }),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    for (final c in _containers.values) {
      c.dispose();
    }
    for (final n in _repaints.values) {
      n.dispose();
    }
    _containers.clear();
    _repaints.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = Stopwatch()..start();

    final tabs = _graph.tabs;
    final activeId = _graph.activeBlueprintId;
    final activeIndex = tabs
        .indexWhere((t) => t.id == activeId)
        .clamp(0, tabs.length - 1);

    final children = <Widget>[];
    for (var i = 0; i < tabs.length; i++) {
      final id = tabs[i].id;
      final container = _ensureContainer(id);
      final repaint = _ensureRepaint(id);

      children.add(
        // Keep each tab’s provider container alive across switches.
        UncontrolledProviderScope(
          key: ValueKey('canvas_scope_$id'),
          container: container,
          child: TickerMode(
            enabled: i == activeIndex,
            child: CanvasScene(tabId: id, repaint: repaint),
          ),
        ),
      );
    }

    final stack = IndexedStack(index: activeIndex, children: children);

    sw.stop();
    dev.log(
      '[perf] Host.build (on switch): ${sw.elapsedMicroseconds / 1000.0} ms',
      name: 'badbadnode.perf',
    );

    // (Optional) Debug: verify viewport does NOT reset on switch
    final vpNow = _ensureContainer(activeId).read(viewportProvider);
    if (vpNow != Rect.zero) {
      final w = vpNow.width.toInt(), h = vpNow.height.toInt();
      dev.log(
        '[perf] Host.build active viewport persists: ${w}x$h',
        name: 'badbadnode.perf',
      );
    }

    return stack;
  }
}
