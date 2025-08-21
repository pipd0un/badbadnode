// lib/src/panel/panel_api.dart
//
// Public API for registering "panel apps" (Explorer, Search, SCM, Debug, Extensions, …)
// so host applications can inject custom tools into the side panel, similar to how
// nodes are injected via `registerNode()`.
//
// This file intentionally avoids Riverpod state; instead it provides a small
// process-wide registry with broadcast streams. Riverpod providers can bridge
// to this registry (see providers/panel_provider.dart).

import 'dart:async' show StreamController;

import 'simple_panel.dart' show PanelApp;

class PanelRegistry {
  PanelRegistry._();
  static final PanelRegistry instance = PanelRegistry._();

  final List<PanelApp> _apps = <PanelApp>[];
  String _activeId = '';

  final StreamController<List<PanelApp>> _appsCtrl =
      StreamController<List<PanelApp>>.broadcast();
  final StreamController<String> _activeCtrl =
      StreamController<String>.broadcast();

  List<PanelApp> get apps => List.unmodifiable(_apps);
  String get activeId => _activeId;

  Stream<List<PanelApp>> get appsChanges => _appsCtrl.stream;
  Stream<String> get activeChanges => _activeCtrl.stream;

  void register(PanelApp app) {
    // Replace if same id exists, otherwise insert keeping order stable.
    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx >= 0) {
      _apps[idx] = app;
    } else {
      _apps.add(app);
      _apps.sort((a, b) {
        final c = a.order.compareTo(b.order);
        if (c != 0) return c;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }

    // If there is no active id, or the current active id was removed earlier,
    // default to the first app.
    if (_activeId.isEmpty || !_apps.any((a) => a.id == _activeId)) {
      _activeId = _apps.isNotEmpty ? _apps.first.id : '';
      _activeCtrl.add(_activeId);
    }

    _appsCtrl.add(apps);
  }

  void unregister(String id) {
    final removedActive = _activeId == id;
    _apps.removeWhere((a) => a.id == id);
    _appsCtrl.add(apps);
    if (removedActive) {
      _activeId = _apps.isNotEmpty ? _apps.first.id : '';
      _activeCtrl.add(_activeId);
    }
  }

  void activate(String id) {
    if (id == _activeId) return;
    if (!_apps.any((a) => a.id == id)) return;
    _activeId = id;
    _activeCtrl.add(_activeId);
  }
}