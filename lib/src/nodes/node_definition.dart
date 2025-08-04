// lib/nodes/node_definition.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/node.dart';
import '../core/evaluator.dart' show GraphEvaluator;

/// ──────────────────────────────────────────────────────────────
///  Base class every node (built-in or plugin) must extend
/// ──────────────────────────────────────────────────────────────
abstract class NodeDefinition {
  /// Unique identifier, e.g. `"number"`
  String get type;

  /// Things that should run once when the graph starts like Object should be 'true'
  bool get isInitializer => false;

  ///  Commands are allowed to mutate evaluator state or do I/O.
  ///  Pure nodes return data only.  Default = false for backwards-compat.
  bool get isCommand => false;

  /// Ordered list of input / output names.
  List<String> get inputs;
  List<String> get outputs;

  /// Initial values that become `node.data`
  Map<String, dynamic> get initialData;

  /// Build the inspector / editor widget.
  Widget buildWidget(Node node, WidgetRef ref);

  /// Runtime executor - may be `async`.
  Future<dynamic> run(Node node, GraphEvaluator eval);
}

/// Registry singleton – any `NodeDefinition` registers itself here.
class NodeRegistry {
  NodeRegistry._();
  static final NodeRegistry _inst = NodeRegistry._();
  factory NodeRegistry() => _inst;

  final Map<String, NodeDefinition> _defs = {};

  NodeDefinition register(NodeDefinition def) {
    if (_defs.containsKey(def.type)) {
      throw Exception('Node type "${def.type}" already registered');
    }
    _defs[def.type] = def;
    return def;
  }

  NodeDefinition? operator [](String type) => _defs[type];
  Iterable<NodeDefinition> get all => _defs.values;

  /// Read-only view keyed by node-type
  Map<String, NodeDefinition> get map => Map.unmodifiable(_defs);

  /// Convenience lookup – returns null if type unknown
  NodeDefinition? lookup(String type) => _defs[type];
}

/// ──────────────────────────────────────────────────────────────
///  Custom Node Registry – for plugin authors to register custom nodes
class CustomNodeRegistry {
  CustomNodeRegistry._();
  static final CustomNodeRegistry _inst = CustomNodeRegistry._();
  factory CustomNodeRegistry() => _inst;

  final Map<String, NodeDefinition> _nodes = {};
  final Map<String, String> _categories = {};

  void register(NodeDefinition n, {String category = 'Others'}) {
    if (_nodes.containsKey(n.type)) {
      throw Exception('Node type "${n.type}" already registered');
    }
    _nodes[n.type] = n;
    _categories[n.type] = category;
    NodeRegistry().register(n);
  }

  Map<String, NodeDefinition> get all => Map.unmodifiable(_nodes);
  
  Map<String, List<NodeDefinition>> get groupedByCategory {
    final Map<String, List<NodeDefinition>> result = {};
    for (final entry in _nodes.entries) {
      final category = _categories[entry.key] ?? 'Others';
      result.putIfAbsent(category, () => []).add(entry.value);
    }
    return result;
  }
}
