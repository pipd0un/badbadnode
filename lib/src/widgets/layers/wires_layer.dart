// lib/src/widgets/layers/wires_layer.dart
//
// Paints *all* static + live wires.  Rebuilds automatically when the
// Graph’s connection list changes (Riverpod).  Live-drag offset still
// comes from [dragDeltaNotifier] so only selected wires animate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/connection.dart' show Connection;
import '../../painter/wire_painter.dart';
import '../../providers/graph/graph_state_provider.dart' show graphProvider;
import '../../providers/ui/port_position_provider.dart' show portPositionProvider;
import '../../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../../providers/ui/viewport_provider.dart' show viewportProvider;
import '../node_drag_wrapper.dart' show dragDeltaNotifier;

/// WiresLayer keeps a per-canvas cache of last-known port centres so that wires
/// stay visually stable while ports re-measure. The cache is scoped to the
/// widget instance (per tab), avoiding cross-tab leakage.
class WiresLayer extends ConsumerStatefulWidget {
  const WiresLayer({super.key});

  @override
  ConsumerState<WiresLayer> createState() => _WiresLayerState();
}

class _WiresLayerState extends ConsumerState<WiresLayer> {
  final Map<String, Offset> _lastKnownPortCenters = <String, Offset>{};

  @override
  Widget build(BuildContext context) {
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
          final last = portId.lastIndexOf('_');
          if (last <= 0) return '';
          final secondLast = portId.lastIndexOf('_', last - 1);
          if (secondLast <= 0) return '';
          return portId.substring(0, secondLast);
        }

        // Build a merged map that falls back to last-known coordinates if a port
        // hasn't reported this frame yet.
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
        final List<Connection> visibleCons;
        if (vp == Rect.zero) {
          visibleCons = graph.connections;
        } else {
          final list = <Connection>[];
          for (final c in graph.connections) {
            final a = endpoint(c.fromPortId);
            final b = endpoint(c.toPortId);
            if (a == null || b == null) continue;
            if (intersects(a, b, screenRect)) list.add(c);
          }
          visibleCons = list;
        }

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
