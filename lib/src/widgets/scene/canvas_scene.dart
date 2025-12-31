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
  // Fixed logical canvas size; large enough for typical blueprints.
  static const double _sceneWidth = 5000.0;
  static const double _sceneHeight = 10000.0;
  static const double _sceneGrowPaddingX = 1000.0;
  static const double _sceneGrowPaddingY = 1000.0;
  static const double _sceneGrowSnap = 1000.0;
  static const double _estimatedNodeWidth = 160.0;
  static const double _estimatedNodeHeight = 80.0;

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
    _tc.dispose();
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
    }
  }

  double _snapUp(double value, double step) {
    if (step <= 0) return value;
    return (value / step).ceil() * step;
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
    final viewport = Rect.fromPoints(tl, br);
    _publishViewportIfChanged(viewport);

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

  Size _sceneSizeFromLiveDrag({
    required Graph graph,
    required Set<String> selected,
    required Offset delta,
  }) {
    if (selected.isEmpty) return const Size(0, 0);
    if (delta == Offset.zero) return const Size(0, 0);

    double maxX = 0.0;
    double maxY = 0.0;

    for (final id in selected) {
      final n = graph.nodes[id];
      if (n == null) continue;
      final x0 = (n.data['x'] as num?)?.toDouble() ?? 0.0;
      final y0 = (n.data['y'] as num?)?.toDouble() ?? 0.0;
      final x = x0 + delta.dx;
      final y = y0 + delta.dy;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    // Expand to include the dragged node's footprint, not just its origin.
    final neededWidthRaw = maxX + _estimatedNodeWidth + _sceneGrowPaddingX;
    final neededHeightRaw = maxY + _estimatedNodeHeight + _sceneGrowPaddingY;

    final neededWidth =
        neededWidthRaw < _sceneWidth ? _sceneWidth : neededWidthRaw;
    final neededHeight =
        neededHeightRaw < _sceneHeight ? _sceneHeight : neededHeightRaw;

    return Size(_snapUp(neededWidth, _sceneGrowSnap), _snapUp(neededHeight, _sceneGrowSnap));
  }

  /// Compute a canvas size that grows to fit the furthest node, but never
  /// shrinks below the fixed base size. This runs only on occasional rebuilds
  /// (drag start/end, host resize), so it doesn't affect pan smoothness.
  Size _computeSceneSize(Graph graph) {
    double maxX = 0.0, maxY = 0.0;
    for (final n in graph.nodes.values) {
      final x = (n.data['x'] as num?)?.toDouble() ?? 0.0;
      final y = (n.data['y'] as num?)?.toDouble() ?? 0.0;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    // Extra padding beyond the furthest node so you can keep building outward.
    const double paddingX = 1000.0;
    const double paddingY = 1000.0;

    final double width =
        (maxX + paddingX) > _sceneWidth ? (maxX + paddingX) : _sceneWidth;
    final double height =
        (maxY + paddingY) > _sceneHeight ? (maxY + paddingY) : _sceneHeight;

    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    // Detect host size changes WITHOUT scheduling a post-frame every build.
    final Widget child = Consumer(
      builder: (context, ref, _) {
        final canvasKey = ref.watch(connectionCanvasKeyProvider);
        final dragging = ref.watch(nodeDraggingProvider);
        final graph = ref.watch(graphProvider);
        final selected = ref.watch(selectedNodesProvider);
        final viewport = ref.watch(viewportProvider);

        return LayoutBuilder(
          builder: (context, constraints) {
            final host = constraints.biggest;
            if (host.isFinite && !host.isEmpty && host != _lastHostSize) {
              _lastHostSize = host;
              // trigger a single recompute after layout settles
              scheduleMicrotask(_onTransformChanged);
            }

            final sizeFromGraph = _computeSceneSize(graph);

            final sizeFromViewport = viewport.isEmpty
                ? const Size(_sceneWidth, _sceneHeight)
                : Size(
                    _snapUp(
                      (viewport.right + _sceneGrowPaddingX) < _sceneWidth
                          ? _sceneWidth
                          : (viewport.right + _sceneGrowPaddingX),
                      _sceneGrowSnap,
                    ),
                    _snapUp(
                      (viewport.bottom + _sceneGrowPaddingY) < _sceneHeight
                          ? _sceneHeight
                          : (viewport.bottom + _sceneGrowPaddingY),
                      _sceneGrowSnap,
                    ),
                  );

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
                      ref.read(connectionStartPortProvider.notifier).state =
                          null;
                      ref.read(connectionDragPosProvider.notifier).state = null;
                    },
                    child: SelectionLayer(
                      canvasKey: canvasKey,
                      child: ValueListenableBuilder<Offset>(
                        valueListenable: dragDeltaNotifier,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: _GridPaintProxy(tabId: widget.tabId),
                              ),
                            ),
                            VirtualizedCanvas(
                              canvasKey: canvasKey,
                              controller: _tc,
                            ),
                            const PreviewLayer(),
                          ],
                        ),
                        builder: (context, delta, child) {
                          final liveDragSize = dragging
                              ? _sceneSizeFromLiveDrag(
                                  graph: graph,
                                  selected: selected,
                                  delta: delta,
                                )
                              : const Size(0, 0);

                          final sceneSize = Size(
                            [
                              sizeFromGraph.width,
                              sizeFromViewport.width,
                              liveDragSize.width,
                            ].reduce((a, b) => a > b ? a : b),
                            [
                              sizeFromGraph.height,
                              sizeFromViewport.height,
                              liveDragSize.height,
                            ].reduce((a, b) => a > b ? a : b),
                          );

                          return SizedBox(
                            key: canvasKey,
                            width: sceneSize.width,
                            height: sceneSize.height,
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // IMPORTANT:
    // Wrap the canvas subtree in a *nested* Navigator so any routes pushed from
    // inside the canvas (e.g., ACustomScreen from a node body) get pushed onto
    // this local Navigator. This ensures they inherit the same ProviderContainer
    // as the active canvas tab (the UncontrolledProviderScope created per-tab),
    // fixing cases where screens couldn’t see state set in the canvas container
    // (e.g., "No VNScene injected yet").
    return Navigator(
      key: ValueKey('canvas_nav_${widget.tabId}'),
      onGenerateInitialRoutes: (navigator, initialRoute) => [
        MaterialPageRoute(
          builder: (_) => child,
          settings: const RouteSettings(name: 'canvas'),
        ),
      ],
    );
  }
}
