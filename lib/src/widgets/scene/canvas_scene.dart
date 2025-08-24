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

  /// Dynamically compute a growable canvas size based on:
  ///  • current viewport (so panning/zooming never shows empty space)
  ///  • current node extents (so dropping/placing far away expands the sheet)
  Size _computeSceneSize() {
    // Read graph + viewport
    final graph = ref.read(graphProvider);
    final vp = ref.read(viewportProvider);

    // Scan node extents (only x/y are used; width/height are padded generously)
    double maxX = 0.0, maxY = 0.0;
    for (final n in graph.nodes.values) {
      final x = (n.data['x'] as num?)?.toDouble() ?? 0.0;
      final y = (n.data['y'] as num?)?.toDouble() ?? 0.0;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    // Heuristics:
    //   • NodeWidget nominal width: ~160
    //   • Add generous headroom so we don't resize every few pixels during edits
    const double nodeWidthGuess = 160.0;
    const double headroom = 2000.0; // extra space beyond furthest content

    // Minimums driven by what's currently visible on screen
    final double minWFromViewport =
        (vp.isEmpty ? _lastHostSize.width : vp.right) + headroom * 0.5;
    final double minHFromViewport =
        (vp.isEmpty ? _lastHostSize.height : vp.bottom) + headroom * 0.5;

    // Minimums driven by graph content
    final double minWFromNodes = maxX + nodeWidthGuess + headroom;
    final double minHFromNodes = maxY + 600.0 + headroom; // rough node height + headroom

    // Fallback so a blank canvas still has working area
    const double absoluteFloor = 2048.0;

    double width = minWFromViewport;
    if (minWFromNodes > width) width = minWFromNodes;
    if (width < absoluteFloor) width = absoluteFloor;

    double height = minHFromViewport;
    if (minHFromNodes > height) height = minHFromNodes;
    if (height < absoluteFloor) height = absoluteFloor;

    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    final canvasKey = ref.watch(connectionCanvasKeyProvider);
    final dragging = ref.watch(nodeDraggingProvider);
    final _ = ref.watch(viewportProvider); // keep viewport-driven rebuilds

    // Detect host size changes WITHOUT scheduling a post-frame every build.
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final host = constraints.biggest;
        if (host.isFinite && !host.isEmpty && host != _lastHostSize) {
          _lastHostSize = host;
          // trigger a single recompute after layout settles
          scheduleMicrotask(_onTransformChanged);
        }

        // ← Dynamic scene size: grows with viewport and node extents
        final sceneSize = _computeSceneSize();

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
                    width: sceneSize.width,
                    height: sceneSize.height,
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
