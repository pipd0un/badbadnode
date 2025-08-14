// lib/src/widgets/tab_host.dart

import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/graph_controller.dart';
import '../core/graph_events.dart'
    show
        ActiveBlueprintChanged,
        BlueprintOpened,
        BlueprintClosed,
        BlueprintRenamed,
        TabGraphChanged,
        TabGraphCleared;
import '../painter/grid_painter.dart' show GridPainterCache;
import '../providers/graph_state_provider.dart'
    show graphProvider, GraphStateByTabNotifier;
import '../providers/ui/canvas_providers.dart'
    show activeCanvasTickProvider;
import '../providers/ui/viewport_provider.dart' show viewportProvider;
import 'scene_builder.dart' show CanvasScene;

class TabHost extends ConsumerStatefulWidget {
  const TabHost({super.key});

  @override
  ConsumerState<TabHost> createState() => _TabHostState();
}

class _TabHostState extends ConsumerState<TabHost> {
  late final GraphController _graph;
  late final List<StreamSubscription> _subs;

  /// Per-tab layout-dirty flag (set when graph changed while tab was inactive).
  final Map<String, bool> _layoutDirty = {};

  /// Optional per-tab activation “tick”. We keep it for compatibility and
  /// update it directly inside each tab’s container if we really need to poke.
  final Map<String, int> _ticks = {};

  /// Persist a dedicated ProviderContainer per tab so **tab switches do not
  /// recreate ProviderScopes**.
  final Map<String, ProviderContainer> _containers = {};

  /// Explicit per-tab repaint tickers used to force one paint on activation
  /// so ProbePaintOnce always runs (no reliance on fallback).
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
      '[perf] TabHost._createContainer($tabId) took ${sw.elapsedMicroseconds / 1000.0} ms',
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
          '[perf] TabHost.onActiveBlueprintChanged listener: ${sw.elapsedMilliseconds} ms',
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
    final activeIndex =
        tabs.indexWhere((t) => t.id == activeId).clamp(0, tabs.length - 1);

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
      '[perf] TabHost.build (on switch): ${sw.elapsedMicroseconds / 1000.0} ms',
      name: 'badbadnode.perf',
    );

    // (Optional) Debug: verify viewport does NOT reset on switch
    final vpNow = _ensureContainer(activeId).read(viewportProvider);
    if (vpNow != Rect.zero) {
      final w = vpNow.width.toInt(), h = vpNow.height.toInt();
      dev.log('[perf] TabHost.build active viewport persists: ${w}x$h',
          name: 'badbadnode.perf');
    }

    return stack;
  }
}
