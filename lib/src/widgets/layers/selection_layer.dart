// lib/widgets/layers/selection_layer.dart

import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../painter/selection_rectangle_painter.dart' show SelectionRectPainter;
import '../../providers/graph/graph_controller_provider.dart' show graphControllerProvider;
import '../../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../../providers/ui/selection_rectangle_provider.dart' show selectionRectCurrentProvider, selectionRectStartProvider;

class SelectionLayer extends ConsumerWidget {
  final GlobalKey canvasKey;
  final Widget child;
  const SelectionLayer({
    super.key,
    required this.canvasKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selStart   = ref.watch(selectionRectStartProvider);
    final selCurrent = ref.watch(selectionRectCurrentProvider);
    final graph      = ref.read(graphControllerProvider);

    void compute() {
      final s = ref.read(selectionRectStartProvider);
      final c = ref.read(selectionRectCurrentProvider);
      if (s == null || c == null) return;
      final rect = Rect.fromPoints(s, c);
      final ids = <String>[];
      for (final n in graph.nodes.values) {
        final x = (n.data['x'] as num).toDouble();
        final y = (n.data['y'] as num).toDouble();
        const size = Size(160, 80);
        if (rect.overlaps(Rect.fromLTWH(x, y, size.width, size.height))) {
          ids.add(n.id);
        }
      }
      ref.read(selectedNodesProvider.notifier)
        ..clear()
        ..selectAll(ids);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      supportedDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      },
      onPanStart: (d) {
        final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(d.globalPosition);
        ref.read(selectionRectStartProvider.notifier).state   = local;
        ref.read(selectionRectCurrentProvider.notifier).state = local;
      },
      onPanUpdate: (d) {
        if (ref.read(selectionRectStartProvider) != null) {
          final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          ref.read(selectionRectCurrentProvider.notifier).state =
              box.globalToLocal(d.globalPosition);
        }
      },
      onPanEnd: (_) {
        compute();
        ref.read(selectionRectStartProvider.notifier).state   = null;
        ref.read(selectionRectCurrentProvider.notifier).state = null;
      },
      child: Stack(
        children: [
          child,
          if (selStart != null && selCurrent != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SelectionRectPainter(
                    selStart: selStart,
                    selCurrent: selCurrent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
