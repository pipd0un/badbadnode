// lib/painter/grid_painter.dart

import 'dart:developer' as dev;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GridPainterCache {
  static final Map<String, _GridCacheEntry> _byTab = {};

  static void evict(String tabId) {
    _byTab.remove(tabId);
  }
}

Rect _normalizeViewport(Rect r) {
  // Normalize to reduce floating jitter between frames/tabs.
  final l = r.left.floorToDouble();
  final t = r.top.floorToDouble();
  final w = r.width.ceilToDouble();
  final h = r.height.ceilToDouble();
  return Rect.fromLTWH(l, t, w, h);
}

class _GridCacheEntry {
  final Rect viewportNorm;
  final double gridSize;
  final Color lineColor;
  final double lineWidth;
  final int labelEvery;
  final double labelFontSize;
  final int labelColorValue;
  final ui.Picture picture;

  _GridCacheEntry({
    required this.viewportNorm,
    required this.gridSize,
    required this.lineColor,
    required this.lineWidth,
    required this.labelEvery,
    required this.labelFontSize,
    required this.labelColorValue,
    required this.picture,
  });

  bool matches({
    required Rect viewport,
    required double gridSize,
    required Color lineColor,
    required double lineWidth,
    required int labelEvery,
    required TextStyle labelStyle,
  }) {
    final v = _normalizeViewport(viewport);
    return viewportNorm == v &&
        this.gridSize == gridSize &&
        this.lineColor == lineColor &&
        this.lineWidth == lineWidth &&
        this.labelEvery == labelEvery &&
        labelFontSize == (labelStyle.fontSize ?? 10) &&
        labelColorValue ==
            (labelStyle.color?.value ?? const Color(0xFF9E9E9E).value);
  }
}

/// A grid painter that uses per-tab cached pictures to make tab switching instant.
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
      dev.log('[perf] GridPainter.paint skipped (no viewport yet)',
          name: 'badbadnode.perf');
      return;
    }

    final sw = Stopwatch()..start();

    // Try cache
    final cached = GridPainterCache._byTab[tabId];
    if (cached != null &&
        cached.matches(
          viewport: viewport,
          gridSize: gridSize,
          lineColor: lineColor,
          lineWidth: lineWidth,
          labelEvery: labelEvery,
          labelStyle: labelStyle,
        )) {
      canvas.drawPicture(cached.picture);
      sw.stop();
      dev.log(
        '[perf] GridPainter.paint cache HIT in ${(sw.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} ms',
        name: 'badbadnode.perf',
      );
      return;
    }

    // Build new picture
    final recorder = ui.PictureRecorder();
    final picCanvas = Canvas(recorder);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth;

    final vr = viewport;

    picCanvas.save();
    picCanvas.clipRect(vr);

    // Compute grid bounds.
    double firstX = (vr.left / gridSize).floorToDouble() * gridSize;
    double lastX = (vr.right / gridSize).ceilToDouble() * gridSize;
    double firstY = (vr.top / gridSize).floorToDouble() * gridSize;
    double lastY = (vr.bottom / gridSize).ceilToDouble() * gridSize;

    // Vertical lines + top labels
    for (double x = firstX; x <= lastX; x += gridSize) {
      picCanvas.drawLine(Offset(x, vr.top), Offset(x, vr.bottom), paint);
      final idx = (x / gridSize).round();
      if (labelEvery > 0 && idx % labelEvery == 0) {
        final label = idx == 0 ? '0' : x.toInt().toString();
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(picCanvas, Offset(x + 2, vr.top + 2));
      }
    }

    // Horizontal lines + left labels
    for (double y = firstY; y <= lastY; y += gridSize) {
      picCanvas.drawLine(Offset(vr.left, y), Offset(vr.right, y), paint);
      final idy = (y / gridSize).round();
      if (labelEvery > 0 && idy % labelEvery == 0) {
        final label = idy == 0 ? '0' : y.toInt().toString();
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(picCanvas, Offset(vr.left + 2, y + 2));
      }
    }

    picCanvas.restore();

    final picture = recorder.endRecording();
    GridPainterCache._byTab[tabId] = _GridCacheEntry(
      viewportNorm: _normalizeViewport(viewport),
      gridSize: gridSize,
      lineColor: lineColor,
      lineWidth: lineWidth,
      labelEvery: labelEvery,
      labelFontSize: labelStyle.fontSize ?? 10,
      labelColorValue: (labelStyle.color ?? Colors.grey).value,
      picture: picture,
    );

    // Composite the freshly built picture
    canvas.drawPicture(picture);

    sw.stop();
    dev.log(
      '[perf] GridPainter.paint cache MISS, recorded in ${sw.elapsedMicroseconds / 1000.0} ms',
      name: 'badbadnode.perf',
    );
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
