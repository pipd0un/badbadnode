// lib/widgets/scene_builder.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../painter/grid_painter.dart' show GridPainter;
import '../providers/connection/connection_providers.dart'
    show connectionStartPortProvider, connectionDragPosProvider;
import '../providers/ui/canvas_providers.dart' show connectionCanvasKeyProvider;
import '../providers/ui/interaction_providers.dart' show nodeDraggingProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;
import 'context_menu_handler.dart' show ContextMenuHandler;
import 'layers/preview_layer.dart' show PreviewLayer;
import 'layers/selection_layer.dart' show SelectionLayer;
import 'layers/viewer_layer.dart' show ViewerLayer;
import 'virtualized_canvas.dart' show VirtualizedCanvas;

class SceneBuilder extends ConsumerStatefulWidget {
  const SceneBuilder({super.key});

  @override
  ConsumerState<SceneBuilder> createState() => _SceneBuilderState();
}

class _SceneBuilderState extends ConsumerState<SceneBuilder> {
  static const double _sceneWidth = 5000.0;
  static const double _sceneHeight = 10000.0;

  final TransformationController _transformationController =
      TransformationController();

  void updateDragPosIfNeeded(Offset globalPos) {
    final start = ref.read(connectionStartPortProvider);
    if (start == null) return;
    final box = ref.read(connectionCanvasKeyProvider).currentContext
        ?.findRenderObject() as RenderBox?;
    if (box == null) return;
    ref.read(connectionDragPosProvider.notifier).state =
        box.globalToLocal(globalPos);
  }

  @override
  Widget build(BuildContext context) {
    final canvasKey = ref.watch(connectionCanvasKeyProvider);
    final dragging = ref.watch(nodeDraggingProvider);

    return ContextMenuHandler(
      canvasKey: canvasKey,
      child: Listener(
        onPointerHover: (e) => updateDragPosIfNeeded(e.position),
        onPointerMove: (e) => updateDragPosIfNeeded(e.position),
        onPointerUp: (_) =>
            ref.read(connectionDragPosProvider.notifier).state = null,
        child: ViewerLayer(
          transformationController: _transformationController,
          panEnabled: !dragging,
          scaleEnabled: !dragging,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              ref.read(selectedNodesProvider.notifier).clear();
              ref.read(connectionStartPortProvider.notifier).state = null;
              ref.read(connectionDragPosProvider.notifier).state = null;
            },
            child: SelectionLayer(
              canvasKey: canvasKey,
              child: SizedBox(
                key: canvasKey,
                width: _sceneWidth,
                height: _sceneHeight,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: GridPainter()),
                      ),
                    ),
                    VirtualizedCanvas(
                      canvasKey: canvasKey,
                      controller: _transformationController,
                    ),
                    const PreviewLayer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
