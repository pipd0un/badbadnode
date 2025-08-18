// lib/src/painter/grid_painter.dart
//
// Lightweight grid painter optimized for continuous zoom/pan.
// Draws directly to the canvas (no picture recording).
// Keeps labels aligned to scene coordinates.

import 'dart:developer' as dev;
import 'package:flutter/material.dart';

class GridPainterCache {
  // No-op cache placeholder to keep callers (Host) compatible.
  static void evict(String tabId) {}
}

class GridPainter extends CustomPainter {
  final String tabId;

  final double gridSize;
  final Color lineColor;
  final double lineWidth;
  final TextStyle labelStyle;
  final int labelEvery;

  /// Scene-space visible rect.
  final Rect viewport;

  const GridPainter({
    required this.tabId,
    required this.viewport,
    this.gridSize = 20.0,
    this.lineColor = const Color.fromARGB(255, 66, 59, 59),
    this.lineWidth = 1.0,
    this.labelStyle = const TextStyle(color: Colors.grey, fontSize: 10),
    this.labelEvery = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (viewport.isEmpty) {
      dev.log('[perf] GridPainter.paint skipped (no viewport yet)', name: 'badbadnode.perf');
      return;
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth;

    final vr = viewport;

    // Compute grid bounds snapped to grid step.
    double firstX = (vr.left / gridSize).floorToDouble() * gridSize;
    double lastX  = (vr.right / gridSize).ceilToDouble() * gridSize;
    double firstY = (vr.top / gridSize).floorToDouble() * gridSize;
    double lastY  = (vr.bottom / gridSize).ceilToDouble() * gridSize;

    // Clip to viewport so we don't overdraw.
    canvas.save();
    canvas.clipRect(vr);

    // Vertical lines + top labels
    for (double x = firstX; x <= lastX; x += gridSize) {
      canvas.drawLine(Offset(x, vr.top), Offset(x, vr.bottom), paint);
      final idx = (x / gridSize).round();
      if (labelEvery > 0 && idx % labelEvery == 0) {
        final label = idx == 0 ? '0' : x.toInt().toString();
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, vr.top + 2));
      }
    }

    // Horizontal lines + left labels
    for (double y = firstY; y <= lastY; y += gridSize) {
      canvas.drawLine(Offset(vr.left, y), Offset(vr.right, y), paint);
      final idy = (y / gridSize).round();
      if (labelEvery > 0 && idy % labelEvery == 0) {
        final label = idy == 0 ? '0' : y.toInt().toString();
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(vr.left + 2, y + 2));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GridPainter old) =>
      old.tabId != tabId ||
      old.gridSize != gridSize ||
      old.lineColor != lineColor ||
      old.lineWidth != lineWidth ||
      old.labelEvery != labelEvery ||
      old.labelStyle != labelStyle ||
      old.viewport != viewport;
}
