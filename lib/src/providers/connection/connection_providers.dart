// lib/providers/connection/connection_providers.dart

// Only UI-gesture helpers remain.  The actual connection list lives in
// the immutable Graph (see graphProvider).

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Port where the “create-wire” drag began (an output pin).
final connectionStartPortProvider = StateProvider<String?>((_) => null);

/// Current mouse position in canvas-local coordinates while dragging
/// the preview wire.
final connectionDragPosProvider  = StateProvider<Offset?>((_) => null);
