// lib/src/controller/graph_controller.globals.dart

part of 'graph_controller.core.dart';

// ───────────────── globals (per tab) ─────────────────

mixin _GlobalsMixin on _GraphCoreBase {
  Map<String, dynamic> get globals => _doc.globals;
  void setGlobal(String k, dynamic v) => _doc.globals[k] = v;
  dynamic getGlobal(String k) => _doc.globals[k];

  bool get globalsBootstrapped => _doc.globalsBootstrapped;
  set globalsBootstrapped(bool v) => _doc.globalsBootstrapped = v;

  /// Reset all global state and mark globals as needing initialization.
  @override
  void resetGlobals() {
    _doc.globals.clear();
    _doc.globalsBootstrapped = false;
  }
}
