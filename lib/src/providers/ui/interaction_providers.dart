// lib/providers/ui/interaction_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the user is currently dragging a node,
/// to disable InteractiveViewer’s pan/scale while dragging.
final nodeDraggingProvider = StateProvider<bool>((_) => false);
