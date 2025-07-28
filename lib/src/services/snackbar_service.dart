// lib/services/snackbar_service.dart
//
// Single-line helper used by runtime nodes that want to pop a SnackBar
// but have no BuildContext / WidgetRef at hand.

import 'package:flutter/material.dart';

class SnackbarService {
  /// Set once from main.dart; afterwards any code can call show(…).
  static GlobalKey<ScaffoldMessengerState>? messengerKey;

  /// Show a short SnackBar if the key is already available.
  static void show(String message) {
    messengerKey?.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 200),
      ),
    );
  }
}
