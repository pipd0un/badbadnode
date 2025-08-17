// lib/src/widgets/scene/probe_paint_once.dart
part of '../host.dart';

class ProbePaintOnce extends CustomPainter {
  const ProbePaintOnce({super.repaint});

  @override
  void paint(Canvas canvas, Size size) {
    // Defer to end of paint so we're measuring *visual* readiness.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      PerfSwitchProbe.markCanvasPainted();
    });
  }

  // Kept for compatibility with older calls; now a no-op.
  static void reset() {}

  @override
  bool shouldRepaint(covariant ProbePaintOnce oldDelegate) => false;
}
