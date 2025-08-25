// lib/node.dart
library;

export 'src/plugin_api.dart' show registerNode;

export 'src/core/evaluator.dart' show GraphEvaluator;
export 'src/core/controller/graph_controller.core.dart' show GraphController;
export 'src/core/graph_events.dart';

export 'src/models/node.dart' show Node;

export 'src/nodes/simple_node.dart' show NodeActions, InPort, OutPort;
export 'src/nodes/simple_node.dart' show SimpleNode;

export 'src/widgets/node_widget.dart' show GenericNodeWidget;
export 'src/widgets/host.dart' show Host;
export 'src/widgets/toolbar.dart' show Toolbar;

export 'src/providers/app_providers.dart';
export 'src/providers/asset_provider.dart' show assetFilesProvider;
export 'src/providers/panel_provider.dart' show panelAppsProvider, activePanelIdProvider;

export 'src/panel_api.dart'
    show
        PanelApp,
        Panels,
        AssetMeta,
        registerPanelApp,
        unregisterPanelApp,
        panelPublishAssets,
        panelClearAssets,
        panelAddAsset,
        panelRemoveAssetByPath,
        activatePanel;

export 'src/page_api.dart'
    show
        PageTabContext,
        PageBuilder,
        registerPageRenderer,
        unregisterPageRenderer,
        openPageTab,
        markTabAsPage;

export 'src/providers/hooks.dart'
    show
        BeforeCloseTabHook,
        HostInitHook,
        beforeCloseTabHookProvider,
        hostInitHookProvider;

export 'src/services/snackbar_service.dart' show SnackbarService;