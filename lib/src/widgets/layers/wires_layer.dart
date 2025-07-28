// lib/widgets/layers/wires_layer.dart
//
// Paints *all* static + live wires.  Rebuilds automatically when the
// Graph’s connection list changes (Riverpod).  Live-drag offset still
// comes from [dragDeltaNotifier] so only selected wires animate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../painter/wire_painter.dart';
import '../../providers/graph_state_provider.dart' show graphProvider;
import '../../providers/ui/port_position_provider.dart' show portPositionProvider;
import '../../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../node_drag_wrapper.dart' show dragDeltaNotifier;

class WiresLayer extends ConsumerWidget {
  const WiresLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph      = ref.watch(graphProvider);
    final positions  = ref.watch(portPositionProvider);
    final selected   = ref.watch(selectedNodesProvider);

    // ValueListenable keeps animated offset cheap during drags
    return ValueListenableBuilder(
      valueListenable: dragDeltaNotifier,
      builder: (_, Offset delta, __) {
        final painter = WirePainter(
          graph.connections,
          positions,
          delta,
          selected,
        );
        return Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: painter, isComplex: true),
            ),
          ),
        );
      },
    );
  }
}
