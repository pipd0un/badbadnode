// lib/src/providers/panel_provider.dart
//
// Riverpod bridge providers that reflect the process-wide PanelRegistry
// (see src/panel/panel_api.dart). UI can simply `watch(panelAppsProvider)`
// and `watch(activePanelIdProvider)` to render the Activity Bar and the
// currently active panel, while plugins use the public API to register.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../panel/simple_panel.dart' show PanelApp;
import '../panel_api.dart'
    show
        $panelAppsSnapshot,
        $activePanelIdSnapshot,
        $panelAppsStream,
        $activePanelIdStream,
        activatePanel;

final panelAppsProvider =
    NotifierProvider<PanelAppsNotifier, List<PanelApp>>(
  () => PanelAppsNotifier(),
);

class PanelAppsNotifier extends Notifier<List<PanelApp>> {
  StreamSubscription? _sub;

  @override
  List<PanelApp> build() {
    // Seed current snapshot, then subscribe to changes.
    state = $panelAppsSnapshot();
    _sub = $panelAppsStream().listen((apps) => state = apps);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return state;
  }
}

final activePanelIdProvider =
    NotifierProvider<ActivePanelIdNotifier, String>(
  () => ActivePanelIdNotifier(),
);

class ActivePanelIdNotifier extends Notifier<String> {
  StreamSubscription? _sub;

  @override
  String build() {
    state = $activePanelIdSnapshot();
    _sub = $activePanelIdStream().listen((id) => state = id);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return state;
  }

  /// UI-side setter that also informs the global registry so external callers
  /// remain in sync.
  void setActive(String id) {
    if (state == id) return;
    state = id;
    activatePanel(id);
  }
}
