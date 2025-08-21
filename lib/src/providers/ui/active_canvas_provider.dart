// lib/src/providers/ui/active_canvas_container.dart
//
// Lightweight bridge so UI outside the canvas ProviderContainer (like the
// Toolbar) can dispatch provider changes into the *active* canvas container.
// Host updates this on tab switches.

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveCanvasContainerLink {
  ActiveCanvasContainerLink._();
  static final ActiveCanvasContainerLink instance = ActiveCanvasContainerLink._();

  ProviderContainer? _container;

  ProviderContainer? get container => _container;
  set container(ProviderContainer? c) => _container = c;

  /// Convenience: run [fn] with the active container if available,
  /// otherwise fall back to [fallback] (e.g. root ref.container path).
  T withActive<T>({
    required T Function(ProviderContainer c) fn,
    required T Function() fallback,
  }) {
    final c = _container;
    if (c != null) return fn(c);
    return fallback();
  }
}
