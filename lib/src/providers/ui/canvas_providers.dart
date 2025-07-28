// lib/providers/ui/canvas_providers.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global key for the ConnectionCanvas, so we can convert global→local positions.
final connectionCanvasKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());
