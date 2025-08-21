// lib/src/widgets/toolbar.dart

import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller/graph_controller.core.dart' show GraphController;
import '../core/graph_events.dart'
    show
        GraphChanged,
        ActiveBlueprintChanged,
        BlueprintOpened,
        BlueprintClosed,
        BlueprintRenamed;
import '../providers/app_providers.dart' show scaffoldMessengerKeyProvider;
import '../providers/graph/graph_controller_provider.dart'
    show graphControllerProvider;

// NEW: decoupled hook for "before close tab" snapshot logic
import '../providers/hooks.dart' show beforeCloseTabHookProvider;
import '../providers/ui/active_canvas_provider.dart' show ActiveCanvasContainerLink;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;

part 'toolbar/paste_json_dialog.dart';
part 'toolbar/toolbar_actions.dart';
part 'toolbar/tab_strip.dart';
part 'toolbar/tab_chip.dart';
part 'toolbar/thin_divider.dart';

// Heights kept identical to original file to avoid layout changes.
const double _kTopBarHeight = 32.0; // (top)
const double _kTabBarHeight = 28.0; // (tabs)

// Computes the smallest available "Blueprint N" title among existing tabs.
String _computeNextBlueprintTitle(GraphController graph) {
  final used = <int>{};
  for (final t in graph.tabs) {
    final m = RegExp(r'^Blueprint\s+(\d+)$').firstMatch(t.title);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      if (n != null) used.add(n);
    }
  }
  var n = 1;
  while (used.contains(n)) {
    n++;
  }
  return 'Blueprint $n';
}

class Toolbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const Toolbar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(60.0); // 32 (top) + 28 (tabs)
  @override
  createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<Toolbar> {
  late final GraphController _graph;
  late final List<StreamSubscription> _subs;

  @override
  void initState() {
    super.initState();
    _graph = ref.read(graphControllerProvider);
    // Rebuild immediately on events so tab chip highlight updates in the same frame.
    _subs = [
      _graph.on<GraphChanged>().listen((_) {
        if (mounted) setState(() {});
      }),
      _graph.on<ActiveBlueprintChanged>().listen((_) {
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintOpened>().listen((_) {
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintClosed>().listen((_) {
        if (mounted) setState(() {});
      }),
      _graph.on<BlueprintRenamed>().listen((_) {
        if (mounted) setState(() {});
      }),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 14,
      color: Color.fromARGB(255, 255, 116, 116),
    );

    return AppBar(
      toolbarHeight: _kTopBarHeight,
      backgroundColor: const Color.fromARGB(255, 41, 40, 40),
      title: const Text('BadBad/Node', style: titleStyle),
      titleSpacing: 8,
      actions: [
        // Main actions (undo/redo, run, select/clear, copy/paste/load)
        ToolbarActions(graph: _graph, isWeb: kIsWeb),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_kTabBarHeight),
        child: RepaintBoundary(
          child: _TabsStrip(controller: _graph, height: _kTabBarHeight),
        ),
      ),
    );
  }
}
