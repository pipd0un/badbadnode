// lib/src/panel/simple_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

typedef PanelBuilder = Widget Function(BuildContext context, WidgetRef ref);

class PanelApp {
  /// Stable unique id, e.g. "explorer", "search", "scm", "debug", "extensions",
  /// or "com.example.my_panel".
  final String id;

  /// Human-readable title shown in tooltip and accessibility.
  final String title;

  /// Material icon for the Activity Bar.
  final IconData icon;

  /// Optional sort key. Lower comes first (defaults to 100).
  final int order;

  /// Builder for the panel body.
  final PanelBuilder builder;

  const PanelApp({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.order = 100,
  });
}