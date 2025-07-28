// lib/providers/ui/port_position_provider.dart

import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PortPositionNotifier extends StateNotifier<Map<String, Offset>> {
  PortPositionNotifier() : super(const {});

  /// Add/update a port centre
  void set(String portId, Offset pos) {
    final existing = state[portId];
    // avoid noisy rebuilds for sub-pixel changes
    if (existing != null && (existing - pos).distance < .1) return;
    state = {...state, portId: pos};
  }

  /// Remove a port 'after' the current build-frame finished.
  /// This prevents Riverpod’s "tried to modify provider while building" error
  /// when many PortWidgets unmount at once (e.g. during big drags).
  void remove(String portId) {
    Future<void>.microtask(() {
      state = {...state}..remove(portId);
    });
  }
}

final portPositionProvider =
    StateNotifierProvider<PortPositionNotifier, Map<String, Offset>>(
  (ref) => PortPositionNotifier(),
);
