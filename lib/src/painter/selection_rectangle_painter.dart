// lib/painter/selection_rectangle_painter.dart

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';

class SelectionRectPainter extends CustomPainter {
  final Offset selStart;
  final Offset selCurrent;
  SelectionRectPainter({required this.selStart, required this.selCurrent});

  static final Paint _fillPaint = Paint()
    ..color = const Color.fromARGB(94, 33, 149, 243)
    ..style = PaintingStyle.fill;
  static final Paint _borderPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(selStart, selCurrent);
    canvas.drawRect(rect, _fillPaint);
    canvas.drawRect(rect, _borderPaint);
  }

  @override
  bool shouldRepaint(covariant SelectionRectPainter old) =>
      old.selStart != selStart || old.selCurrent != selCurrent;
}