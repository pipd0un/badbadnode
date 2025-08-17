// lib/src/widgets/scene/grid_paint_proxy.dart
part of '../host.dart';

/// Small proxy so GridPainter rebuilds only when viewport changes.
class _GridPaintProxy extends ConsumerWidget {
  const _GridPaintProxy({required this.tabId});
  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vr = ref.watch(viewportProvider);
    return CustomPaint(painter: GridPainter(tabId: tabId, viewport: vr));
  }
}
