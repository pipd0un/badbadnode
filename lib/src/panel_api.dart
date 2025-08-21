// lib/src/panel_api.dart
import 'panel/panel_definition.dart' show PanelRegistry;
import 'panel/simple_panel.dart' show PanelApp;
export 'panel/simple_panel.dart' show PanelApp;

/// Register a side panel app/extension.
void registerPanelApp(PanelApp app) => PanelRegistry.instance.register(app);

/// Unregister a side panel app/extension by id.
void unregisterPanelApp(String id) => PanelRegistry.instance.unregister(id);

/// Programmatically activate a panel by id (e.g., when a plugin wants to reveal itself).
void activatePanel(String id) => PanelRegistry.instance.activate(id);

// Internal hooks for providers:
List<PanelApp> $panelAppsSnapshot() => PanelRegistry.instance.apps;
String $activePanelIdSnapshot() => PanelRegistry.instance.activeId;
Stream<List<PanelApp>> $panelAppsStream() => PanelRegistry.instance.appsChanges;
Stream<String> $activePanelIdStream() => PanelRegistry.instance.activeChanges;
