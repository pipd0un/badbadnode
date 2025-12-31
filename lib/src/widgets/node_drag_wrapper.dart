// lib/widgets/node_drag_wrapper.dart

// During a drag we do **NOT** touch the GraphController.
// I only update a global ValueNotifier<Offset> so that
// every selected node applies the same Transform.translate.
//
// When the pointer is released we commit the accumulated
// delta with graph.moveNode / snapNodeToGrid – exactly once.
//
// Only the nodes inside the current selection rebuild per-frame;
// the rest of the canvas stays put – so single-node drags are
// super-light, and multi-selection drags scale a lot better.
// Selected-state is tracked with _isSelected (no ref.watch in build)
// I subscribe once in initState with ref.listenManual → ProviderSubscription

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/node.dart';
import '../providers/ui/interaction_providers.dart' show nodeDraggingProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../providers/graph/graph_controller_provider.dart' show graphControllerProvider;
import 'node_widget.dart' show NodeWidget;

/// Global delta shared by all nodes in the current drag-group.
final ValueNotifier<Offset> dragDeltaNotifier = ValueNotifier(Offset.zero);

class NodeDragWrapper extends ConsumerStatefulWidget {
  const NodeDragWrapper({super.key, required this.node});
  final Node node;

  @override
  ConsumerState<NodeDragWrapper> createState() =>
      _NodeDragWrapperState();
}

class _NodeDragWrapperState extends ConsumerState<NodeDragWrapper> {
  bool _isSelected = false;
  late final ProviderSubscription<Set<String>> _sub;

  @override
  void initState() {
    super.initState();

    // Initial value
    _isSelected =
        ref.read(selectedNodesProvider).contains(widget.node.id);

    // Listen for membership flips only
    _sub = ref.listenManual<Set<String>>(
      selectedNodesProvider,
      (previous, next) {
        final was  = previous?.contains(widget.node.id) ?? false;
        final curr = next.contains(widget.node.id);
        if (was != curr) setState(() => _isSelected = curr);
      },
    );
  }

  @override
  void dispose() {
    _sub.close();                          // stop listening
    super.dispose();
  }

  bool _isLeader = false;                  // node where the gesture began

  void _onPanStart(DragStartDetails _) {
    final sel = ref.read(selectedNodesProvider);

    if (!sel.contains(widget.node.id)) {
      // 1st: make this node the only selection *immediately*
      ref.read(selectedNodesProvider.notifier).replaceWith(widget.node.id);
      // 2nd: sync local flag so no other node is translated on first frame
      setState(() => _isSelected = true);
    }

    _isLeader = true;
    dragDeltaNotifier.value = Offset.zero;
    ref.read(nodeDraggingProvider.notifier).state = true;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isLeader) {
      dragDeltaNotifier.value += d.delta;  // notify selected nodes/wires
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_isLeader) return;

    final graph = ref.read(graphControllerProvider);
    final sel   = ref.read(selectedNodesProvider);
    final dx    = dragDeltaNotifier.value.dx;
    final dy    = dragDeltaNotifier.value.dy;

    graph.runBatch<void>(() {
      for (final id in sel) {
        graph.moveNode(id, dx, dy);
        graph.snapNodeToGrid(id);
      }
    });

    dragDeltaNotifier.value = Offset.zero;
    _isLeader = false;
    ref.read(nodeDraggingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    Widget inner = NodeWidget(node: widget.node);

    // Only selected nodes apply the live translate
    if (_isSelected && ref.watch(nodeDraggingProvider)) {
      inner = ValueListenableBuilder<Offset>(
        valueListenable: dragDeltaNotifier,
        builder: (_, offset, child) =>
            Transform.translate(offset: offset, child: child),
        child: inner,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onTap: () {
        if (!ref.read(nodeDraggingProvider)) {
          final selNot = ref.read(selectedNodesProvider.notifier);
          _isSelected
              ? selNot.deselect(widget.node.id)
              : selNot.select(widget.node.id);
        }
      },
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: inner,
    );
  }
}
