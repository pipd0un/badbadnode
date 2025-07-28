// lib/painter/preview_painter.dart

import 'package:flutter/material.dart';

class PreviewPainter extends CustomPainter {
  final String startPortId;
  final Offset dragTo;
  final Map<String, Offset> portPositions;

  PreviewPainter({
    required this.startPortId,
    required this.dragTo,
    required this.portPositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final from = portPositions[startPortId];
    if (from == null) return;
    final midY = (from.dy + dragTo.dy) / 2;
    final paint =
        Paint()
          ..color = const Color.fromARGB(178, 33, 149, 243)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    final path =
        Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(from.dx, midY, dragTo.dx, midY, dragTo.dx, dragTo.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PreviewPainter old) {
    return old.startPortId != startPortId ||
        old.dragTo != dragTo ||
        old.portPositions != portPositions;
  }
}
