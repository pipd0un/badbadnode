// lib/widgets/layers/nodes_layer.dart
//
// Rebuilds when the immutable Graph changes *structure*.
// Each node has a stable ValueKey to keep its State paired correctly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/graph_state_provider.dart' show graphProvider;
import '../node_drag_wrapper.dart' show NodeDragWrapper;

class NodesLayer extends ConsumerWidget {
  const NodesLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref
        .watch(graphProvider)
        .nodes
        .values
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // stable order

    return Stack(
      children: [
        for (final n in nodes)
          Positioned(
            left: (n.data['x'] as num).toDouble(),
            top : (n.data['y'] as num).toDouble(),
            child: RepaintBoundary(
              child: NodeDragWrapper(
                key : ValueKey<String>(n.id),
                node: n,
              ),
            ),
          ),
      ],
    );
  }
}

// I'm not sure switching to builder below. 
// It makes smoother panning experience till graph gets node-heavy being.

// This can not pass the performance-test.
// @override
// Widget build(BuildContext context, WidgetRef ref) {
//   final graphNodes = ref.watch(graphProvider).nodes.values.toList()
//     ..sort((a, b) => a.id.compareTo(b.id));

//   final vp = ref.watch(viewportProvider);
//   // pad a bit so items just outside the screen are ready to show
//   final visible = vp == Rect.zero ? vp : vp.inflate(400.0);

//   // conservative node bounds (same as selection layer)
//   const nodeSize = Size(160, 80);

//   final nodes = [
//     for (final n in graphNodes)
//       if (visible == Rect.zero ||
//           Rect.fromLTWH(
//             (n.data['x'] as num).toDouble(),
//             (n.data['y'] as num).toDouble(),
//             nodeSize.width,
//             nodeSize.height,
//           ).overlaps(visible))
//         n
//   ];

//   return Stack(
//     children: [
//       for (final n in nodes)
//         Positioned(
//           left: (n.data['x'] as num).toDouble(),
//           top : (n.data['y'] as num).toDouble(),
//           child: RepaintBoundary(
//             child: NodeDragWrapper(
//               key : ValueKey<String>(n.id),
//               node: n,
//             ),
//           ),
//         ),
//     ],
//   );
// }