// lib/src/widgets/virtualized_canvas.dart

part of '../host.dart';

class VirtualizedCanvas extends ConsumerStatefulWidget {
  final GlobalKey canvasKey;
  final TransformationController controller;
  const VirtualizedCanvas({
    super.key,
    required this.canvasKey,
    required this.controller,
  });

  @override
  ConsumerState<VirtualizedCanvas> createState() =>
      _VirtualizedCanvasState();
}

class _VirtualizedCanvasState extends ConsumerState<VirtualizedCanvas> {
  @override
  Widget build(BuildContext context) {
    // The heavy work is done in child layers.
    return Stack(
      children: [
        const RepaintBoundary(child: NodesLayer()),
        Positioned.fill(
          child: RepaintBoundary(
            child: const WiresLayer(),
          ),
        ),
      ],
    );
  }
}
