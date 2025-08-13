// lib/providers/ui/viewport_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final viewportProvider = StateProvider<Rect>((_) => Rect.zero);
