// lib/providers/ui/port_position_provider.dart

import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PortPositionNotifier extends StateNotifier<Map<String, Offset>> {
  PortPositionNotifier() : super(const {});

  // ── micro-batching buffers ─────────────────────────────────────────────
  final Map<String, Offset> _stagedSet = <String, Offset>{};
  final Set<String> _stagedRemove = <String>{};
  bool _scheduled = false;

  void _scheduleFlush() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Merge all staged sets/removes in a single state write.
      var next = {...state, ..._stagedSet};
      for (final id in _stagedRemove) {
        next.remove(id);
      }
      _stagedSet.clear();
      _stagedRemove.clear();
      _scheduled = false;
      state = next;
    });
  }

  /// Add/update a port centre (batched – at most one state write per frame).
  void set(String portId, Offset pos) {
    final existing = state[portId];
    // avoid noisy staging for sub-pixel/no-op changes
    if (existing != null && (existing - pos).distance < .1) return;
    _stagedRemove.remove(portId);
    _stagedSet[portId] = pos;
    _scheduleFlush();
  }

  /// Remove a port (batched – at most one state write per frame).
  void remove(String portId) {
    _stagedSet.remove(portId);
    _stagedRemove.add(portId);
    _scheduleFlush();
  }
}

final portPositionProvider =
    StateNotifierProvider<PortPositionNotifier, Map<String, Offset>>(
  (ref) => PortPositionNotifier(),
);
