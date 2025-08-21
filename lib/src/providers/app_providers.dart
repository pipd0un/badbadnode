// lib/providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global ScaffoldMessengerKey, to show SnackBar.
final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>((ref) {
  return GlobalKey<ScaffoldMessengerState>();
});

/// Side panel visibility and width.
final sidePanelVisibleProvider = StateProvider<bool>((ref) => true);
final sidePanelWidthProvider = StateProvider<double>((ref) => 260.0);
final sidePanelCollapsedProvider = StateProvider<bool>((ref) => false);
