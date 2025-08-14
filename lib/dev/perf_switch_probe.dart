// dev/perf_switch_probe.dart
import 'dart:developer' as dev;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A tight, single-frame latency probe:
/// start() at onTapDown; end() automatically on the *first* canvas paint.
class PerfSwitchProbe {
  static String? _id;
  static final Stopwatch _sw = Stopwatch();
  static FrameCallback? _frameCb;
  static bool _armed = false;

  /// Call from the tab chip's onTapDown.
  static void start(String tabId) {
    // Re-arm cleanly.
    cancel();

    _id = tabId;
    _armed = true;
    _sw
      ..reset()
      ..start();

    // 1) Make sure at least one frame is scheduled even if nothing else changes.
    SchedulerBinding.instance.scheduleFrame();

    // 2) Fallback: if for some reason we never get a paint signal,
    //    stop at the very next frame end.
    _frameCb = (Duration _) async {
      _frameCb = null;
      // Wait for the frame to complete layout/paint/raster.
      await WidgetsBinding.instance.endOfFrame;
      _stop('FIRST_FRAME_ONLY');
    };
    SchedulerBinding.instance.addPostFrameCallback(_frameCb!);
  }

  /// Call from the canvas on first paint after a switch.
  static void markCanvasPainted() {
    // Stop only if a probe is armed.
    if (!_armed) return;
    _stop('CANVAS_PAINTED');
  }

  static double _refreshRateHz() {
    try {
      final pd = WidgetsBinding.instance.platformDispatcher;
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
    // remove pending fallback if still registered
    if (_frameCb != null) {
      // no direct remove API; just ignore by nulling (_frameCb runs once)
      _frameCb = null;
    }
  }
}
