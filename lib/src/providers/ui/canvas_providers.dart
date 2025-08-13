// lib/providers/ui/canvas_providers.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global key for the ConnectionCanvas, so we can convert global→local positions.
final connectionCanvasKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());

/// A small per-canvas "activation tick".
/// When a tab becomes active, TabHost bumps this integer for that tab’s scope.
/// Port widgets watch it and re-report their positions immediately, so wires
/// and hit-testing are correct without waiting for any user interaction.
final activeCanvasTickProvider = StateProvider<int>((_) => 0);
