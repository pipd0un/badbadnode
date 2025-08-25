// lib/src/widgets/host.dart
//
// Host: entry widget that manages tabs (blueprints) and renders the active
// CanvasScene. Replaces the old SceneBuilder+TabHost pair.

import 'dart:async';

import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller/graph_controller.core.dart' show GraphController;
// events
import '../core/graph_events.dart'
    show
        ActiveBlueprintChanged,
        BlueprintOpened,
        BlueprintClosed,
        BlueprintRenamed,
        TabGraphChanged,
        TabGraphCleared;
import '../painter/grid_painter.dart' show GridPainter, GridPainterCache;
import '../providers/app_providers.dart'
    show 
        sidePanelVisibleProvider, 
        sidePanelWidthProvider;
// IMPORTANT: Share the *same* asset provider instance across all per-tab
// ProviderContainers, so mounting/unmounting from the Toolbar (root scope)
// immediately reflects inside node widgets that live in per-tab scopes.
import '../providers/asset_provider.dart' show assetFilesProvider;
import '../providers/connection/connection_providers.dart'
    show 
        connectionStartPortProvider, 
        connectionDragPosProvider;
import '../providers/graph/graph_state_provider.dart'
    show 
        GraphStateByTabNotifier, 
        graphProvider;
// decoupled host bootstrap hook (apps can override this)
import '../providers/hooks.dart' show hostInitHookProvider;
// bridge so Toolbar can target the *active canvas* container
import '../providers/ui/active_canvas_provider.dart' show ActiveCanvasContainerLink;
import '../providers/ui/canvas_providers.dart'
    show
        activeCanvasTickProvider,
        connectionCanvasKeyProvider,
        canvasScaleProvider;
import '../providers/ui/interaction_providers.dart' show nodeDraggingProvider;
import '../providers/ui/port_position_provider.dart'
    show 
        portPositionProvider, 
        portPositionsEpochProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../providers/ui/viewport_provider.dart' show viewportProvider;
// ⬇ NEW: bridge panel-published assets to GraphController.globals["assets"]
import '../services/asset_service.dart' show AssetHub;
// ⬇ NEW: page embedder (custom tab pages)
import '../services/page_embedder.dart' show PageEmbedder;
// utils
import 'context_menu_handler.dart' show ContextMenuHandler;
import 'layers/nodes_layer.dart' show NodesLayer;
import 'layers/preview_layer.dart' show PreviewLayer;
import 'layers/selection_layer.dart' show SelectionLayer;
import 'layers/viewer_layer.dart' show ViewerLayer;
// layers
import 'layers/wires_layer.dart' show WiresLayer;
import 'panel_host.dart' show SidePanelHost;

// ---- Parts (shared imports live in this file) -------------------------------
part 'scene/canvas_scene.dart';
part 'scene/grid_paint_proxy.dart';
part 'scene/virtualized_canvas.dart';

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

  ProviderContainer? _rootContainer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture the root container once and reuse it
    _rootContainer ??= ProviderScope.containerOf(context, listen: false);
  }

  ProviderContainer _createContainer(String tabId) {
    final rootAssetsNotifier = ref.read(assetFilesProvider.notifier);

    final container = ProviderContainer(
      // 👈 CRITICAL: share providers with the app’s root scope
      parent: _rootContainer,
      overrides: [
        // Keep graph scoped per tab
        graphProvider.overrideWith(
          (ref) => GraphStateByTabNotifier(_graph, tabId),
        ),
        // Share the SAME asset notifier instance across tabs
        assetFilesProvider.overrideWith((ref) => rootAssetsNotifier),
      ],
    );

    _containers[tabId] = container;
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

  /// Sanitize stored port positions for [tabId] against the tab's current graph,
  /// then request a re-measure of surviving ports.
  void _sanitizePortsForTab(String tabId) {
    final c = _ensureContainer(tabId);
    // Read the per-tab graph from its own container scope.
    final graph = c.read(graphProvider);
    final nodeIds = graph.nodes.keys.toSet();

    // Drop stale positions (nodes that no longer exist).
    c.read(portPositionProvider.notifier).pruneByNodeIds(nodeIds);

    // Ask all PortWidgets in this scope to re-measure once post-frame.
    final epoch = c.read(portPositionsEpochProvider);
    c.read(portPositionsEpochProvider.notifier).state = epoch + 1;
  }

  void _updateActiveContainerLink(String id) {
    ActiveCanvasContainerLink.instance.container = _ensureContainer(id);
  }

  List<PlatformFile> _platformAssetsFromHub() => [
        for (final m in AssetHub.instance.assets)
          PlatformFile(
            name: m.fileName,
            path: m.path,
            size: m.size ?? (m.bytes?.length ?? 0),
            bytes: m.bytes, // ← crucial for Web/MemoryImage
          ),
      ];

  @override
  void initState() {
    super.initState();
    // Keep parity with previous behavior (direct instance).
    _graph = GraphController();

    // ⬇ Seed globals["assets"] once at startup (PlatformFile list for legacy nodes).
    _graph.setGlobal('assets', _platformAssetsFromHub());

    // Let host apps bootstrap (e.g., rename initial tab to "main", register panels, etc.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hook = ref.read(hostInitHookProvider);
      if (hook != null) {
        hook(_graph, ref);
      }
    });

    // ⬇ Attach graph to the PageEmbedder so page API can open tabs at runtime.
    PageEmbedder.instance.attachGraph(_graph);

    // Seed first tab’s container + state
    final active = _graph.activeBlueprintId;
    _ticks[active] = 0;
    _layoutDirty[active] = false;
    _ensureContainer(active);
    _ensureRepaint(active);
    _updateActiveContainerLink(active); // <<< bridge: expose active canvas container

    _subs = [
      // ⬇ Keep GraphController.globals["assets"] in sync with panel assets.
      AssetHub.instance.changes.listen((_) {
        _graph.setGlobal('assets', _platformAssetsFromHub());
        // Evaluator also refreshes this on each run; this makes it visible to nodes that read globals directly.
      }),

      _graph.on<ActiveBlueprintChanged>().listen((e) {
        // Ensure a repaint for ProbePaintOnce on the activated tab.
        _ensureRepaint(e.id).value++;

        // Bridge: make Toolbar target the correct container.
        _updateActiveContainerLink(e.id);

        // If the tab’s layout changed while inactive, poke it once.
        if (_layoutDirty[e.id] == true) {
          _sanitizePortsForTab(e.id); // ← normalize ports on activation
          _bumpTick(e.id);
          _layoutDirty[e.id] = false;
        }

        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintOpened>().listen((e) {
        _ticks.putIfAbsent(e.id, () => 0);
        _layoutDirty.putIfAbsent(e.id, () => false);
        _ensureContainer(e.id);
        _ensureRepaint(e.id);

        // If newly opened is also active (typical), update the bridge.
        _updateActiveContainerLink(_graph.activeBlueprintId);

        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintClosed>().listen((e) {
        // Keep PageEmbedder registry in sync.
        PageEmbedder.instance.onTabClosed(e.id);

        // IMPORTANT: Delay disposing the ProviderContainer until AFTER the widget
        // subtree that uses it has been removed from the tree. Disposing it
        // immediately can race with in-flight pointer/hover events that still
        // hit the old CanvasScene, causing:
        //   "Bad state: Tried to read a provider from a ProviderContainer that was already disposed"
        _ticks.remove(e.id);
        _layoutDirty.remove(e.id);

        // Remove UI first.
        if (mounted) setState(() {});

        // Evict caches and dispose per-tab scopes safely on the next frame.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          GridPainterCache.evict(e.id);
          _disposeContainer(e.id);
          _disposeRepaint(e.id);

          // After close, ensure the bridge points at the current active tab.
          _updateActiveContainerLink(_graph.activeBlueprintId);
        });
      }),
      _graph.on<BlueprintRenamed>().listen((_) {
        // Title in Toolbar updates via controller; page context title is best-effort.
        // (We don't depend on event payload here since Host didn't either.)
        if (mounted) setState(() {});
      }),
      _graph.on<TabGraphChanged>().listen((e) {
        if (e.id == _graph.activeBlueprintId) {
          _sanitizePortsForTab(e.id); // ← active tab: sanitize immediately
        } else {
          _layoutDirty[e.id] = true; // defer until activation
        }
      }),
      _graph.on<TabGraphCleared>().listen((e) {
        if (e.id == _graph.activeBlueprintId) {
          _sanitizePortsForTab(e.id); // ← active tab: sanitize immediately
        } else {
          _layoutDirty[e.id] = true; // defer until activation
        }
      }),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    // Dispose remaining containers/repaints.
    for (final c in _containers.values) {
      c.dispose();
    }
    for (final n in _repaints.values) {
      n.dispose();
    }
    _containers.clear();
    _repaints.clear();

    // Clear bridges
    ActiveCanvasContainerLink.instance.container = null;
    PageEmbedder.instance.detachGraph();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

      // Decide per-tab renderer: custom page vs canvas scene.
      final pageCtx = PageEmbedder.instance.contextForTab(id);
      final isPage = pageCtx != null;
      final Widget tabChild = isPage
          ? _CustomPageScene(tabId: id) // uses the same per-tab ProviderContainer
          : CanvasScene(tabId: id, repaint: repaint);

      children.add(
        // Keep each tab’s provider container alive across switches.
        UncontrolledProviderScope(
          key: ValueKey('canvas_scope_$id'),
          container: container,
          child: TickerMode(
            enabled: i == activeIndex,
            child: tabChild,
          ),
        ),
      );
    }

    final stack = IndexedStack(index: activeIndex, children: children);
    final showPanel = ref.watch(sidePanelVisibleProvider);
    final panelWidth = ref.watch(sidePanelWidthProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base row lays out the canvas with a left gutter equal to the panel width
        // so content never extends under the panel.
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reserve space only when panel is visible.
            if (showPanel) SizedBox(width: panelWidth),
            Expanded(child: stack),
          ],
        ),

        // Always overlay the panel host so the 8px reopen strip remains tappable.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: showPanel ? panelWidth : 10,
          child: const SidePanelHost(),
        ),
      ],
    );
  }
}

/// Hosts a custom page inside a tab, using the registered PageBuilder.
class _CustomPageScene extends ConsumerWidget {
  final String tabId;
  const _CustomPageScene({required this.tabId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = PageEmbedder.instance.contextForTab(tabId);
    if (ctx == null) {
      // Fallback to an empty box if the page got unregistered mid-flight.
      return const SizedBox.expand();
    }
    final builder = PageEmbedder.instance.builderForKind(ctx.kind);
    if (builder == null) {
      return const Center(
        child: Text(
          'No renderer registered for this page kind.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return builder(context, ref, ctx);
  }
}
