// lib/widgets/layers/preview_layer.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/connection/connection_providers.dart';
import '../../providers/ui/port_position_provider.dart';
import '../../painter/preview_painter.dart';

class PreviewLayer extends ConsumerWidget {
  const PreviewLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startPort = ref.watch(connectionStartPortProvider);
    final dragPos = ref.watch(connectionDragPosProvider);
    if (startPort == null || dragPos == null) {
      return const SizedBox.shrink();
    }
    final portPositions = ref.watch(portPositionProvider);
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: PreviewPainter(
              startPortId: startPort,
              dragTo: dragPos,
              portPositions: portPositions,
            ),
          ),
        ),
      ),
    );
  }
}
