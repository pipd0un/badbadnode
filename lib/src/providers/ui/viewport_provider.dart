import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scene-space visible rect (in canvas coordinates).
/// Updated by CanvasScene when the transform or host size changes.
final viewportProvider = StateProvider<Rect>((_) => Rect.zero);

/// Logical on-screen size of the host (in logical pixels).
/// Updated by ViewportBridge; useful if you ever need the raw screen box.
final screenSizeProvider = StateProvider<Size>((_) => Size.zero);
