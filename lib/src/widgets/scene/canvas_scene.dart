// lib/src/widgets/scene/canvas_scene.dart
part of '../host.dart';

/// CanvasScene: one instance per tab.
class CanvasScene extends ConsumerStatefulWidget {
  const CanvasScene({super.key, required this.tabId, required this.repaint});

  final String tabId;
  final Listenable repaint;

  @override
  ConsumerState<CanvasScene> createState() => _CanvasSceneState();
}

class _CanvasSceneState extends ConsumerState<CanvasScene> {
  static const double _sceneWidth = 5000.0;
  static const double _sceneHeight = 10000.0;

  final TransformationController _tc = TransformationController();

  Rect _lastViewport = Rect.zero;
  Size _lastHostSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransformChanged);
    // Initial viewport after first layout:
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTransformChanged());
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransformChanged);
    super.dispose();
  }

  double _extractScale(Matrix4 m) {
    final sX = m.storage[0];
    final sY = m.storage[5];
    return ((sX.abs() + sY.abs()) * 0.5);
  }

  bool _rectNear(Rect a, Rect b, {double eps = 0.5}) {
    return (a.left - b.left).abs() < eps &&
        (a.top - b.top).abs() < eps &&
        (a.width - b.width).abs() < eps &&
        (a.height - b.height).abs() < eps;
  }

  void _publishViewportIfChanged(Rect rect) {
    if (!_rectNear(rect, _lastViewport)) {
      _lastViewport = rect;
      ref.read(viewportProvider.notifier).state = rect;
      dev.log(
        '[perf] ViewportUpdate scene=${rect.width.toInt()}x${rect.height.toInt()}',
        name: 'badbadnode.perf',
      );
    }
  }

  void _onTransformChanged() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Size screen = box.size;

    // scene-space rect = inverse(transform) applied to the on-screen box
    final inv = Matrix4.inverted(_tc.value);
    final tl = MatrixUtils.transformPoint(inv, Offset.zero);
    final br =
        MatrixUtils.transformPoint(inv, Offset(screen.width, screen.height));
    _publishViewportIfChanged(Rect.fromPoints(tl, br));

    // Scale (publish only on real change)
    final scale = _extractScale(_tc.value);
    final prev = ref.read(canvasScaleProvider);
    if ((prev - scale).abs() > 0.0005) {
      ref.read(canvasScaleProvider.notifier).state = scale;
    }
  }

  void _updateDragPosIfNeeded(Offset globalPos) {
    final start = ref.read(connectionStartPortProvider);
    if (start == null) return;
    final box = ref
        .read(connectionCanvasKeyProvider)
        .currentContext
        ?.findRenderObject() as RenderBox?;
    if (box == null) return;
    ref.read(connectionDragPosProvider.notifier).state =
        box.globalToLocal(globalPos);
  }

  @override
  Widget build(BuildContext context) {
    final canvasKey = ref.watch(connectionCanvasKeyProvider);
    final dragging = ref.watch(nodeDraggingProvider);
    final _ = ref.watch(viewportProvider);

    final sw = Stopwatch()..start();

    // Detect host size changes WITHOUT scheduling a post-frame every build.
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final host = constraints.biggest;
        if (host.isFinite && !host.isEmpty && host != _lastHostSize) {
          _lastHostSize = host;
          // trigger a single recompute after layout settles
          scheduleMicrotask(_onTransformChanged);
        }

        return ContextMenuHandler(
          canvasKey: canvasKey,
          child: Listener(
            onPointerHover: (e) => _updateDragPosIfNeeded(e.position),
            onPointerMove: (e) => _updateDragPosIfNeeded(e.position),
            onPointerUp: (_) =>
                ref.read(connectionDragPosProvider.notifier).state = null,
            child: ViewerLayer(
              transformationController: _tc,
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
                        // 1) Paint grid (cached per-tab)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: _GridPaintProxy(
                              tabId: widget.tabId,
                            ),
                          ),
                        ),
                        // 2) The rest
                        VirtualizedCanvas(
                          canvasKey: canvasKey,
                          controller: _tc,
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
      },
    );

    sw.stop();
    dev.log(
      '[perf] CanvasScene.build: ${sw.elapsedMicroseconds / 1000.0} ms',
      name: 'badbadnode.perf',
    );

    return child;
  }
}
