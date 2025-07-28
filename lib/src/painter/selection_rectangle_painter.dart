// lib/painter/selection_rectangle_painter.dart

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';

class SelectionRectPainter extends CustomPainter {
  final Offset selStart;
  final Offset selCurrent;
  SelectionRectPainter({required this.selStart, required this.selCurrent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(94, 33, 149, 243)
      ..style = PaintingStyle.fill;
    final rect = Rect.fromPoints(selStart, selCurrent);
    canvas.drawRect(rect, paint);

    final border = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant SelectionRectPainter old) =>
      old.selStart != selStart || old.selCurrent != selCurrent;
}