// lib/src/panel_api.dart
//
// Public API for registering "panel apps" (Explorer, Search, SCM, Debug, Extensions, …)
// so host applications can inject custom tools into the side panel, similar to how
// nodes are injected via `registerNode()`.
//
// This file intentionally avoids Riverpod state; instead it provides a small
// process-wide registry with broadcast streams. Riverpod providers can bridge
// to this registry (see providers/panel_provider.dart).

import 'panel/panel_definition.dart' show PanelRegistry;
import 'panel/simple_panel.dart' show PanelApp;
import 'services/asset_service.dart' show AssetHub, AssetMeta;
export 'panel/simple_panel.dart' show PanelApp;
export 'services/asset_service.dart' show AssetMeta; // expose to plugins

class _PanelAssetsBridge {
  _PanelAssetsBridge._();
  static final _PanelAssetsBridge instance = _PanelAssetsBridge._();

  /// Panels call these to publish into the global AssetHub.
  void setAll(List<AssetMeta> items) => AssetHub.instance.setAll(items);
  void clear() => AssetHub.instance.clear();
  void add(AssetMeta a) => AssetHub.instance.add(a);
  void removeByPath(String path) => AssetHub.instance.removeByPath(path);
}

class Panels {
  Panels._();
  static final Panels instance = Panels._();

  // ——— Panel app registry passthrough ———
  void register(PanelApp app) => PanelRegistry.instance.register(app);
  void unregister(String id) => PanelRegistry.instance.unregister(id);
  void activate(String id) => PanelRegistry.instance.activate(id);

  // ——— Asset publishing API (for panel apps) ———
  void publishAssets(List<AssetMeta> all) =>
      _PanelAssetsBridge.instance.setAll(all);

  void clearAssets() => _PanelAssetsBridge.instance.clear();

  void addAsset(AssetMeta a) => _PanelAssetsBridge.instance.add(a);

  void removeAssetByPath(String path) =>
      _PanelAssetsBridge.instance.removeByPath(path);
}

/// Register a side panel app/extension.
void registerPanelApp(PanelApp app) => Panels.instance.register(app);

/// Unregister a side panel app/extension by id.
void unregisterPanelApp(String id) => Panels.instance.unregister(id);

/// Programmatically activate a panel by id (e.g., when a plugin wants to reveal itself).
void activatePanel(String id) => Panels.instance.activate(id);

// Asset publishing helpers for panel apps:
void panelPublishAssets(List<AssetMeta> all) => Panels.instance.publishAssets(all);

void panelClearAssets() => Panels.instance.clearAssets();

void panelAddAsset(AssetMeta a) => Panels.instance.addAsset(a);

void panelRemoveAssetByPath(String path) => Panels.instance.removeAssetByPath(path);

// Internal hooks for providers:
List<PanelApp> $panelAppsSnapshot() => PanelRegistry.instance.apps;
String $activePanelIdSnapshot() => PanelRegistry.instance.activeId;
Stream<List<PanelApp>> $panelAppsStream() => PanelRegistry.instance.appsChanges;
Stream<String> $activePanelIdStream() => PanelRegistry.instance.activeChanges;
