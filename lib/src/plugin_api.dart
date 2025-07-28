// lib/plugin_api.dart

import 'nodes/node_definition.dart' show NodeDefinition, CustomNodeRegistry;

/// Register a custom [NodeDefinition] with the editor.
///
/// Call this exactly once (e.g. at your plugin’s `init` time).
void registerNode(NodeDefinition node) =>
    CustomNodeRegistry().register(node);