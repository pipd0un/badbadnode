// lib/src/painter/wire_painter.dart

import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../models/wire_cache.dart' show CachedPath;
import '../models/connection.dart' show Connection;

class WirePainter extends CustomPainter {
  final List<Connection> cons;
  final Map<String, Offset> ports;
  final Offset dragOffset;
  final Set<String> sel;

  static final _staticCache = <String, CachedPath>{};

  WirePainter(this.cons, this.ports, this.dragOffset, this.sel);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = Stopwatch()..start();

    String nodeIdOf(String portId) {
      final p = portId.split('_');
      return p.sublist(0, p.length - 2).join('_');
    }

    final paint = Paint()
      ..color = const Color.fromARGB(255, 255, 112, 226)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    int drawn = 0;

    for (final c in cons) {
      final a0 = ports[c.fromPortId];
      final b0 = ports[c.toPortId];
      if (a0 == null || b0 == null) continue;

      final aSel = sel.contains(nodeIdOf(c.fromPortId));
      final bSel = sel.contains(nodeIdOf(c.toPortId));

      final a = aSel ? a0 + dragOffset : a0;
      final b = bSel ? b0 + dragOffset : b0;

      if (!aSel && !bSel) {
        final key    = c.id;
        final cached = _staticCache[key];
        if (cached == null || cached.from != a || cached.to != b) {
          final midY = (a.dy + b.dy) / 2;
          final path = Path()
            ..moveTo(a.dx, a.dy)
            ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
          _staticCache[key] = CachedPath(path, a, b);
        }
        canvas.drawPath(_staticCache[key]!.path, paint);
      } else {
        final midY = (a.dy + b.dy) / 2;
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
        canvas.drawPath(path, paint);
      }
      drawn++;
    }

    sw.stop();
    dev.log(
      '[perf] WirePainter.paint: ${sw.elapsedMicroseconds / 1000.0} ms (drawn=$drawn)',
      name: 'badbadnode.perf',
    );
  }

  @override
  bool shouldRepaint(covariant WirePainter old) =>
      old.ports       != ports       ||
      old.dragOffset  != dragOffset  ||
      old.sel         != sel         ||
      old.cons.length != cons.length;
}
