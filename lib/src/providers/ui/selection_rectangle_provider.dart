// lib/providers/ui/selection_rectangle_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the drag‐selection rectangle start and current positions
final selectionRectStartProvider = StateProvider<Offset?>((_) => null);
final selectionRectCurrentProvider = StateProvider<Offset?>((_) => null);
