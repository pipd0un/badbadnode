// lib/widgets/layers/viewer_layer.dart

import 'dart:math';
import 'package:flutter/material.dart';

class ViewerLayer extends StatefulWidget {
  final TransformationController transformationController;
  final bool panEnabled;
  final bool scaleEnabled;
  final Widget child;
  const ViewerLayer({
    super.key,
    required this.transformationController,
    this.panEnabled = true,
    this.scaleEnabled = true,
    required this.child,
  });

  @override
  State<ViewerLayer> createState() =>
      _ClampedInteractiveViewerState();
}

class _ClampedInteractiveViewerState extends State<ViewerLayer> {
  @override
  void initState() {
    super.initState();
    widget.transformationController.addListener(_clampPan);
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_clampPan);
    super.dispose();
  }

  void _clampPan() {
    final m = Matrix4.copy(widget.transformationController.value);
    final t = m.getTranslation();
    final cx = min(0.0, t.x), cy = min(0.0, t.y);
    if (cx != t.x || cy != t.y) {
      m.setTranslationRaw(cx, cy, t.z);
      widget.transformationController.value = m;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: widget.transformationController,
      constrained: false,
      boundaryMargin: EdgeInsets.all(double.infinity),
      minScale: 0.5,
      maxScale: 2.5,
      panEnabled: widget.panEnabled,
      scaleEnabled: widget.scaleEnabled,
      clipBehavior: Clip.none,
      child: widget.child,
    );
  }
}
