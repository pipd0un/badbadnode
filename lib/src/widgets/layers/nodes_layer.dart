// lib/src/widgets/layers/nodes_layer.dart
//
// Rebuilds when the immutable Graph changes *structure*.
// Each node has a stable ValueKey to keep its State paired correctly.

import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/graph_state_provider.dart' show graphProvider;
import '../node_drag_wrapper.dart' show NodeDragWrapper;

class NodesLayer extends ConsumerWidget {
  const NodesLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sw = Stopwatch()..start();

    final nodes = ref
        .watch(graphProvider)
        .nodes
        .values
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // stable order

    final stack = Stack(
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

    sw.stop();
    dev.log(
      '[perf] NodesLayer.build: ${sw.elapsedMicroseconds / 1000.0} ms (nodes=${nodes.length})',
      name: 'badbadnode.perf',
    );

    return stack;
  }
}
