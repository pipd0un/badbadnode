// lib/src/widgets/layers/wires_layer.dart
//
// Paints *all* static + live wires.  Rebuilds automatically when the
// Graph’s connection list changes (Riverpod).  Live-drag offset still
// comes from [dragDeltaNotifier] so only selected wires animate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../painter/wire_painter.dart';
import '../../providers/graph/graph_state_provider.dart' show graphProvider;
import '../../providers/ui/port_position_provider.dart' show portPositionProvider;
import '../../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../../providers/ui/viewport_provider.dart' show viewportProvider;
import '../node_drag_wrapper.dart' show dragDeltaNotifier;

/// File-scoped cache so wires can fall back to last-known endpoints for a frame.
/// This preserves visual continuity when ports haven't re-measured yet.
final Map<String, Offset> _lastKnownPortCenters = <String, Offset>{};

class WiresLayer extends ConsumerWidget {
  const WiresLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph     = ref.watch(graphProvider);
    final positions = ref.watch(portPositionProvider);
    final selected  = ref.watch(selectedNodesProvider);
    final vp        = ref.watch(viewportProvider);

    // Update last-known cache with any fresh measurements first.
    if (positions.isNotEmpty) {
      _lastKnownPortCenters.addAll(positions);
    }

    return ValueListenableBuilder<Offset>(
      valueListenable: dragDeltaNotifier,
      builder: (_, Offset delta, __) {
        // Inflate a bit so near-edge wires still show
        final screenRect = vp == Rect.zero ? vp : vp.inflate(600.0);

        String nodeIdOf(String portId) {
          final p = portId.split('_');
          return p.sublist(0, p.length - 2).join('_');
        }

        // Build a merged map that falls back to last-known coordinates if a port
        // hasn't reported this frame yet. This mirrors pre-0.4.1 continuity.
        final mergedPositions = Map<String, Offset>.from(_lastKnownPortCenters)
          ..addAll(positions);

        // Apply delta to endpoints of wires whose node is selected (being dragged)
        Offset? endpoint(String portId) {
          final base = mergedPositions[portId];
          if (base == null) return null;
          final nid = nodeIdOf(portId);
          return selected.contains(nid) ? base + delta : base;
        }

        bool intersects(Offset a, Offset b, Rect r) {
          if (r == Rect.zero) return true; // no viewport; keep it simple
          if (r.contains(a) || r.contains(b)) return true;
          final minX = a.dx < b.dx ? a.dx : b.dx;
          final maxX = a.dx > b.dx ? a.dx : b.dx;
          final minY = a.dy < b.dy ? a.dy : b.dy;
          final maxY = a.dy > b.dy ? a.dy : b.dy;
          // loose AABB check is enough (cubic stays within these in practice)
          return !(maxX < r.left || minX > r.right || maxY < r.top || minY > r.bottom);
        }

        // Keep viewport culling, but evaluate with merged (fallback) positions.
        final visibleCons = (vp == Rect.zero)
            ? graph.connections
            : [
                for (final c in graph.connections)
                  if (endpoint(c.fromPortId) != null && endpoint(c.toPortId) != null)
                    if (intersects(endpoint(c.fromPortId)!, endpoint(c.toPortId)!, screenRect))
                      c
              ];

        // Use merged positions so WirePainter gets fallback coords.
        final painter = WirePainter(visibleCons, mergedPositions, delta, selected);

        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: painter, isComplex: true),
          ),
        );
      },
    );
  }
}
