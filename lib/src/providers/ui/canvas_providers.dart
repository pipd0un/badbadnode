// lib/providers/ui/canvas_providers.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global key for the ConnectionCanvas, so we can convert global→local positions.
final connectionCanvasKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());

/// A small per-canvas "activation tick".
final activeCanvasTickProvider = StateProvider<int>((_) => 0);
/// Current canvas scale reported by the InteractiveViewer for this canvas.
/// Port widgets watch this and re-measure only when scale changes.
final canvasScaleProvider = StateProvider<double>((_) => 1.0);
