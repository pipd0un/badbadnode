// dev/perf_switch_probe.dart
import 'dart:developer' as dev;
import 'package:flutter/scheduler.dart';

/// A tight, single-frame latency probe:
/// start() at onTapDown; end() on the *first* canvas paint (called directly from paint).
class PerfSwitchProbe {
  static String? _id;
  static final Stopwatch _sw = Stopwatch();
  static bool _armed = false;

  /// Call from the tab chip's onTapDown.
  static void start(String tabId) {
    cancel();

    _id = tabId;
    _armed = true;
    _sw
      ..reset()
      ..start();

    // Ensure at least one frame will be scheduled even if nothing else changes.
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Call directly from the canvas paint of the first visual frame after a switch.
  static void markCanvasPainted() {
    if (!_armed) return;
    _stop('CANVAS_PAINTED');
  }

  static double _refreshRateHz() {
    try {
      final pd = SchedulerBinding.instance.platformDispatcher;
      final view = pd.implicitView ?? (pd.views.isNotEmpty ? pd.views.first : null);
      final hz = view?.display.refreshRate;
      if (hz != null && hz > 0) return hz;
    } catch (_) {}
    return 60.0; // safe default
  }

  static void _stop(String reason) {
    if (!_armed) return;
    _armed = false;

    _sw.stop();
    final elapsedMs = _sw.elapsedMicroseconds / 1000.0;
    final hz = _refreshRateHz();
    final vsyncMs = 1000.0 / hz;
    final workMs = (elapsedMs - vsyncMs);
    final workClamped = workMs < 0 ? 0.0 : workMs;

    dev.log(
      '[perf] TabSwitch("$_id") tap→first-visual-frame=${elapsedMs.toStringAsFixed(1)} ms '
      '[@${hz.toStringAsFixed(0)}Hz ≈1vsync=${vsyncMs.toStringAsFixed(1)} ms, work≈${workClamped.toStringAsFixed(1)} ms] '
      '[$reason]',
      name: 'badbadnode.perf',
    );

    _detach();
  }

  static void cancel() => _detach();

  static void _detach() {
    _id = null;
    _sw.stop();
    _armed = false;
  }
}
