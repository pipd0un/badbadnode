// lib/src/controller/graph_controller.globals.dart

part of 'graph_controller.core.dart';

// ───────────────── globals (per tab) ─────────────────

mixin _GlobalsMixin on _GraphCoreBase {
  Map<String, dynamic> get globals => _activeDoc?.globals ?? _seedGlobals;

  void setGlobal(String k, dynamic v) {
    // Keep a seed so values set before any tab exists are applied to new tabs.
    _seedGlobals[k] = v;
    _activeDoc?.globals[k] = v;
  }

  dynamic getGlobal(String k) => (_activeDoc?.globals ?? _seedGlobals)[k];

  bool get globalsBootstrapped =>
      _activeDoc?.globalsBootstrapped ?? _seedGlobalsBootstrapped;
  set globalsBootstrapped(bool v) {
    _seedGlobalsBootstrapped = v;
    final d = _activeDoc;
    if (d != null) d.globalsBootstrapped = v;
  }

  /// Reset all global state and mark globals as needing initialization.
  @override
  void resetGlobals() {
    final d = _activeDoc;
    if (d == null) return;
    d.globals.clear();
    d.globalsBootstrapped = false;
  }
}
