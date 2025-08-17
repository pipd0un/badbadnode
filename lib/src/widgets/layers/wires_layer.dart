// lib/src/widgets/layers/wires_layer.dart
//
// Paints *all* static + live wires.  Rebuilds automatically when the
// Graph’s connection list changes (Riverpod).  Live-drag offset still
// comes from [dragDeltaNotifier] so only selected wires animate.

import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../painter/wire_painter.dart';
import '../../providers/graph/graph_state_provider.dart' show graphProvider;
import '../../providers/ui/port_position_provider.dart' show portPositionProvider;
import '../../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../../providers/ui/viewport_provider.dart' show viewportProvider;
import '../node_drag_wrapper.dart' show dragDeltaNotifier;

class WiresLayer extends ConsumerWidget {
  const WiresLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph     = ref.watch(graphProvider);
    final positions = ref.watch(portPositionProvider);
    final selected  = ref.watch(selectedNodesProvider);
    final vp        = ref.watch(viewportProvider);

    return ValueListenableBuilder<Offset>(
      valueListenable: dragDeltaNotifier,
      builder: (_, Offset delta, __) {
        final sw = Stopwatch()..start();

        // Inflate a bit so near-edge wires still show
        final screenRect = vp == Rect.zero ? vp : vp.inflate(600.0);

        String nodeIdOf(String portId) {
          final p = portId.split('_');
          return p.sublist(0, p.length - 2).join('_');
        }

        // Apply delta to endpoints of wires whose node is selected (being dragged)
        Offset? endpoint(String portId) {
          final base = positions[portId];
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

        final visibleCons = (vp == Rect.zero)
            ? graph.connections
            : [
                for (final c in graph.connections)
                  if (endpoint(c.fromPortId) != null && endpoint(c.toPortId) != null)
                    if (intersects(endpoint(c.fromPortId)!, endpoint(c.toPortId)!, screenRect))
                      c
              ];

        final painter = WirePainter(visibleCons, positions, delta, selected);

        sw.stop();
        dev.log(
          '[perf] WiresLayer.builder: ${sw.elapsedMicroseconds / 1000.0} ms (wires=${visibleCons.length})',
          name: 'badbadnode.perf',
        );

        return IgnorePointer(
          child: CustomPaint(painter: painter, isComplex: true),
        );
      },
    );
  }
}
