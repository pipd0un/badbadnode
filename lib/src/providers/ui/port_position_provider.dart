// lib/src/providers/ui/port_position_provider.dart

import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PortPositionNotifier extends StateNotifier<Map<String, Offset>> {
  PortPositionNotifier() : super(const {});

  // ── micro-batching buffers ─────────────────────────────────────────────
  final Map<String, Offset> _stagedSet = <String, Offset>{};
  final Set<String> _stagedRemove = <String>{};
  bool _scheduled = false;

  void _flushNow() {
    _scheduled = false;
    if (_stagedSet.isEmpty && _stagedRemove.isEmpty) return;
    var next = {...state, ..._stagedSet};
    for (final id in _stagedRemove) {
      next.remove(id);
    }
    _stagedSet.clear();
    _stagedRemove.clear();
    state = next; // notifies dependents and schedules a new frame
  }

  void _scheduleFlush() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _flushNow();
      }
      _scheduled = false;
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

  /// Clears all known positions (rarely needed).
  void clearAll() {
    _stagedSet.clear();
    _stagedRemove.clear();
    state = const {};
  }

  /// Prune any stored positions that belong to nodes NOT in [nodeIds].
  /// Safe to call after structural graph changes; commits immediately.
  ///
  /// Port IDs are of the form: "{nodeId}_{portName}_{in|out}".
  void pruneByNodeIds(Set<String> nodeIds) {
    if (state.isEmpty) return;
    String nodeIdOf(String portId) {
      final parts = portId.split('_');
      return parts.sublist(0, parts.length - 2).join('_');
    }

    final next = <String, Offset>{};
    state.forEach((pid, off) {
      final nid = nodeIdOf(pid);
      if (nodeIds.contains(nid)) next[pid] = off;
    });

    _stagedSet.clear();
    _stagedRemove.clear();
    _scheduled = false;
    state = next; // immediate commit (no extra frame dependency)
  }

  @override
  void dispose() {
    _stagedSet.clear();
    _stagedRemove.clear();
    _scheduled = false;
    super.dispose();
  }
}

final portPositionProvider =
    StateNotifierProvider<PortPositionNotifier, Map<String, Offset>>(
  (ref) => PortPositionNotifier(),
);

/// Epoch to *request* all PortWidgets to re-measure themselves post-frame.
/// Increment this when node positions are structurally committed
/// (e.g., after drag-end / snap, or after a big paste).
final portPositionsEpochProvider = StateProvider<int>((_) => 0);
