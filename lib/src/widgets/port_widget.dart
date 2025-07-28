// lib/widgets/port_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ui/canvas_providers.dart' show connectionCanvasKeyProvider;
import '../providers/ui/port_position_provider.dart'
    show PortPositionNotifier, portPositionProvider;

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

  @override
  void initState() {
    super.initState();
    // Cache the notifier so we never call ref in dispose.
    _notifier = ref.read(portPositionProvider.notifier);
    _key = GlobalKey();
    SchedulerBinding.instance.addPostFrameCallback((_) => _reportPosition());
  }

  @override
  void didUpdateWidget(covariant PortWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-report on every rebuild.
    SchedulerBinding.instance.addPostFrameCallback((_) => _reportPosition());
  }

  void _reportPosition() {
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
    // ↳ **DO NOT** remove the port here — that causes a brief gap
    //    in your portPositions map and makes wires vanish.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
