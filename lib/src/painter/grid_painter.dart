// lib/painter/grid_painter.dart

import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final double gridSize;
  final Color lineColor;
  final double lineWidth;
  final TextStyle labelStyle;
  final double labelInterval;

  const GridPainter({
    this.gridSize = 20.0,
    this.lineColor = const Color.fromARGB(255, 66, 59, 59),
    this.lineWidth = 1.0,
    this.labelStyle = const TextStyle(color: Colors.grey, fontSize: 10),
    this.labelInterval = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor..strokeWidth = lineWidth;

    // Vertical lines + labels
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      if ((x / gridSize) % labelInterval == 0) {
        final label = x.toInt().toString();
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      }
    }

    // Horizontal lines + labels
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      if ((y / gridSize) % labelInterval == 0) {
        final label = y.toInt().toString();
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(2, y + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter old) =>
      old.gridSize != gridSize ||
      old.lineColor != lineColor ||
      old.lineWidth != lineWidth ||
      old.labelInterval != labelInterval;
}
