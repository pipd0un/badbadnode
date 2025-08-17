// lib/src/widgets/port_widget.dart
//
// Reports canvas-local port centers to the portPositionProvider.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ui/canvas_providers.dart' show canvasScaleProvider, connectionCanvasKeyProvider;
import '../providers/ui/interaction_providers.dart' show nodeDraggingProvider;
import '../providers/ui/port_position_provider.dart' show PortPositionNotifier, portPositionProvider, portPositionsEpochProvider;

/// A circular port that reports its canvas-local centre position so that wires
/// know where to start/end.
class PortWidget extends ConsumerStatefulWidget {
  final String portId;
  final bool isInput;
  const PortWidget({super.key, required this.portId, this.isInput = true});

  @override
  ConsumerState<PortWidget> createState() => _PortWidgetState();
}

class _PortWidgetState extends ConsumerState<PortWidget> {
  late final PortPositionNotifier _notifier;
  late final GlobalKey _key;
  double _lastScale = 1.0;
  bool _lastDragging = false;
  int _seenEpoch = 0;

  @override
  void initState() {
    super.initState();
    // Cache the notifier so we never call ref in dispose.
    _notifier = ref.read(portPositionProvider.notifier);
    _key = GlobalKey();
    SchedulerBinding.instance.addPostFrameCallback((_) => _reportPosition());
  }

  void _reportPosition() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    final canvasBox = ref
        .read(connectionCanvasKeyProvider)
        .currentContext
        ?.findRenderObject() as RenderBox?;
    if (box == null || canvasBox == null) return;

    final globalCenter = box.localToGlobal(box.size.center(Offset.zero));
    final localCenter = canvasBox.globalToLocal(globalCenter);
    _notifier.set(widget.portId, localCenter);
  }

  @override
  void dispose() {
    // Remove this port from the positions map to avoid stale endpoints.
    _notifier.remove(widget.portId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1) Re-measure on scale changes.
    final scale = ref.watch(canvasScaleProvider);
    if ((scale - _lastScale).abs() > 0.0005) {
      _lastScale = scale;
      SchedulerBinding.instance.addPostFrameCallback((_) => _reportPosition());
    }

    // 2) Re-measure right after a drag ends (commit new absolute coords).
    final dragging = ref.watch(nodeDraggingProvider);
    if (_lastDragging && !dragging) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _reportPosition());
    }
    _lastDragging = dragging;

    // 3) Re-measure when a global epoch bump happens (explicit request).
    final epoch = ref.watch(portPositionsEpochProvider);
    if (epoch != _seenEpoch) {
      _seenEpoch = epoch;
      SchedulerBinding.instance.addPostFrameCallback((_) => _reportPosition());
    }

    // 4) Also schedule one post-frame measurement on any build that happens
    // due to layout/position updates (Positioned moved).
    SchedulerBinding.instance.addPostFrameCallback((_) => _reportPosition());

    return Container(
      key: _key,
      width: 12,
      height: 12,
      margin: widget.isInput
          ? const EdgeInsets.only(right: 4)
          : const EdgeInsets.only(left: 4),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 255, 112, 226),
        shape: BoxShape.circle,
      ),
    );
  }
}
