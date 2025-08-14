// lib/src/widgets/virtualized_canvas.dart
//
// Splits the canvas into two layers: nodes (heavy widgets) & wires
// (single CustomPaint).  No EventBus subscription needed anymore –
// Riverpod handles rebuilds when the *graph structure* changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'layers/nodes_layer.dart'  show NodesLayer;
import 'layers/wires_layer.dart'  show WiresLayer;

class VirtualizedCanvas extends ConsumerStatefulWidget {
  final GlobalKey canvasKey;
  final TransformationController controller;
  const VirtualizedCanvas({
    super.key,
    required this.canvasKey,
    required this.controller,
  });

  @override
  ConsumerState<VirtualizedCanvas> createState() =>
      _VirtualizedCanvasState();
}

class _VirtualizedCanvasState extends ConsumerState<VirtualizedCanvas> {
  @override
  Widget build(BuildContext context) {
    // The heavy work is done in child layers.
    return Stack(
      children: [
        const RepaintBoundary(child: NodesLayer()),
        Positioned.fill(
          child: RepaintBoundary(
            child: const WiresLayer(),
          ),
        ),
      ],
    );
  }
}
