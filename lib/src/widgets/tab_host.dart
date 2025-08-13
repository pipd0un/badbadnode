// lib/widgets/tab_host.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/graph_controller.dart';
import '../core/graph_events.dart'
    show
        ActiveBlueprintChanged,
        BlueprintOpened,
        BlueprintClosed,
        BlueprintRenamed;
import '../providers/graph_state_provider.dart'
    show graphProvider, GraphStateByTabNotifier;
import '../providers/ui/canvas_providers.dart'
    show connectionCanvasKeyProvider, activeCanvasTickProvider;
import '../providers/connection/connection_providers.dart'
    show connectionStartPortProvider, connectionDragPosProvider;
import '../providers/ui/interaction_providers.dart' show nodeDraggingProvider;
import '../providers/ui/selection_providers.dart'
    show
        selectedNodesProvider,
        collapsedNodesProvider,
        SelectedNodesNotifier,
        CollapsedNodesNotifier;
import '../providers/ui/port_position_provider.dart'
    show portPositionProvider, PortPositionNotifier;
import '../providers/ui/selection_rectangle_provider.dart'
    show selectionRectStartProvider, selectionRectCurrentProvider;
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

  /// Per-tab "activation ticks" to poke canvases when they become visible.
  final Map<String, int> _ticks = {};

  void _bumpTick(String id) {
    _ticks[id] = (_ticks[id] ?? 0) + 1;
  }

  @override
  void initState() {
    super.initState();
    _graph = GraphController();
    _subs = [
      _graph.on<ActiveBlueprintChanged>().listen((e) {
        _bumpTick(e.id);
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintOpened>().listen((e) {
        _ticks.putIfAbsent(e.id, () => 0);
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintClosed>().listen((_) {
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintRenamed>().listen((_) {
        if (mounted) setState(() {});
      }),
    ];
    // Seed first tab tick so initial canvas reports positions immediately.
    _bumpTick(_graph.activeBlueprintId);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  List<Override> _canvasOverrides(String tabId) {
    // Each canvas gets a brand-new set of UI providers + a tab-scoped graph provider.
    return [
      // Graph for this tab only (override the default active-tab provider)
      graphProvider.overrideWith((ref) => GraphStateByTabNotifier(_graph, tabId)),

      // Canvas-global key (for hit-testing / wire positions)
      connectionCanvasKeyProvider.overrideWith((ref) => GlobalKey()),

      // Wire-drag helpers
      connectionStartPortProvider.overrideWith((ref) => null),
      connectionDragPosProvider.overrideWith((ref) => null),

      // Interaction + selection
      nodeDraggingProvider.overrideWith((ref) => false),
      selectedNodesProvider.overrideWith((ref) => SelectedNodesNotifier()),
      collapsedNodesProvider.overrideWith((ref) => CollapsedNodesNotifier()),

      // Port positions
      portPositionProvider.overrideWith((ref) => PortPositionNotifier()),

      // Selection rectangle + viewport
      selectionRectStartProvider.overrideWith((ref) => null),
      selectionRectCurrentProvider.overrideWith((ref) => null),
      viewportProvider.overrideWith((ref) => Rect.zero),

      // Activation tick for this canvas
      activeCanvasTickProvider.overrideWith((ref) => _ticks[tabId] ?? 0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _graph.tabs;
    final activeId = _graph.activeBlueprintId;
    final activeIndex = tabs.indexWhere((t) => t.id == activeId).clamp(0, tabs.length - 1);

    return Stack(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Offstage(
            offstage: i != activeIndex,
            child: TickerMode(
              enabled: i == activeIndex,
              child: ProviderScope(
                key: ValueKey('canvas_scope_${tabs[i].id}'),
                overrides: _canvasOverrides(tabs[i].id),
                child: const CanvasScene(),
              ),
            ),
          ),
      ],
    );
  }
}
