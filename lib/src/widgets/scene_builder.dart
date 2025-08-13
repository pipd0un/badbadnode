// lib/widgets/scene_builder.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../painter/grid_painter.dart' show GridPainter;
import '../providers/connection/connection_providers.dart'
    show connectionStartPortProvider, connectionDragPosProvider;
import '../providers/ui/canvas_providers.dart' show connectionCanvasKeyProvider;
import '../providers/ui/interaction_providers.dart' show nodeDraggingProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;
import '../providers/ui/viewport_provider.dart' show viewportProvider;
import 'context_menu_handler.dart' show ContextMenuHandler;
import 'layers/preview_layer.dart' show PreviewLayer;
import 'layers/selection_layer.dart' show SelectionLayer;
import 'layers/viewer_layer.dart' show ViewerLayer;
import 'tab_host.dart' show TabHost;
import 'virtualized_canvas.dart' show VirtualizedCanvas;

class SceneBuilder extends StatelessWidget {
  const SceneBuilder({super.key});
  @override
  Widget build(BuildContext context) => const TabHost();
}

/// ─────────────────────────────────────────────────────────
/// CanvasScene: the original canvas implementation from SceneBuilder
/// (unchanged) – used internally by TabHost for each blueprint tab.
/// ─────────────────────────────────────────────────────────
class CanvasScene extends ConsumerStatefulWidget {
  const CanvasScene({super.key});

  @override
  ConsumerState<CanvasScene> createState() => _CanvasSceneState();
}

class _CanvasSceneState extends ConsumerState<CanvasScene> {
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
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    super.dispose();
  }

  void _onTransformChanged() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Size screen = box.size;

    final inv = Matrix4.inverted(_transformationController.value);
    final tl = MatrixUtils.transformPoint(inv, Offset.zero);
    final br =
        MatrixUtils.transformPoint(inv, Offset(screen.width, screen.height));
    final rect = Rect.fromPoints(tl, br);
    ref.read(viewportProvider.notifier).state = rect;
  }

  @override
  Widget build(BuildContext context) {
    final canvasKey = ref.watch(connectionCanvasKeyProvider);
    final dragging = ref.watch(nodeDraggingProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTransformChanged());

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
