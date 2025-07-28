// lib/engine/evaluator.dart

import 'dart:async';

import '../controller/graph_controller.dart';
import '../models/node.dart';
import '../nodes/node_definition.dart' show NodeDefinition, NodeRegistry;

/// Runtime callback signature for every node type.
typedef NodeExecutor = Future<dynamic> Function(Node node, GraphEvaluator eval);

/// Pure-Dart evaluator – no Flutter / Riverpod deps.
class GraphEvaluator {
  GraphEvaluator(
    this.graph,
  );

  final GraphController graph;

  final Map<String, dynamic> _values = {};
  final Set<String> _ranInLoop      = {};
  final Map<String, dynamic> _objects = {};

  // ───────── key-value helpers ─────────
  void setObject(String key, dynamic value) => _objects[key] = value;
  dynamic getObject(String key)             => _objects[key];

  // ───────────────── helpers ─────────────────
  String _nodeIdOfPort(String portId) {
    final parts = portId.split('_');
    // last two parts = direction + pin-name
    return parts.sublist(0, parts.length - 2).join('_');
  }

  List<Node> _topoSort() {
    final nodes = graph.nodes.values.toList();
    final deps  = <String, Set<String>>{
      for (final n in nodes) n.id: <String>{}
    };

    for (final c in graph.connections) {
      // Ignore the run‑time feedback edge “…_in_process”
      if (c.toPortId.contains('_in_process')) continue;
  
      final from = _nodeIdOfPort(c.fromPortId);
      final to   = _nodeIdOfPort(c.toPortId);
      deps[to]!.add(from);
    }

    final visited = <String>{};
    final result  = <Node>[];

    void visit(String id) {
      if (visited.contains(id)) return;
      visited.add(id);
      for (final d in deps[id]!) {
        visit(d);
      }
      result.add(nodes.firstWhere((n) => n.id == id));
    }

    for (final n in nodes) {
      visit(n.id);
    }
    return result;
  }

  NodeDefinition _def(String type) =>
      NodeRegistry().lookup(type) ??
      (throw Exception('No node definition for "$type"'));

  Future<dynamic> _exec(Node node, {String? overrideInput}) {
    final def  = _def(node.type);
    if (overrideInput != null) {
      final data = {...node.data, 'activeInput': overrideInput};
      return def.run(Node(id: node.id, type: node.type, data: data), this);
    }
    return def.run(node, this);
  }

  // ───────────────── public API ─────────────────
  Future<Map<String, dynamic>> run() async {
    _values.clear();
    _ranInLoop.clear();

    final sorted = _topoSort();
    for (final node in sorted) {
      if (_ranInLoop.contains(node.id)) continue;

      if (node.type == 'if') {
        final cond   = input(node, 'bool') as bool? ?? false;
        final branch = cond ? 'true' : 'false';
        _values[node.id] = await _exec(node, overrideInput: branch);
        _ranInLoop.add(node.id);

      } else if (node.type == 'loop') {
        final list = input(node, 'in') as List<dynamic>? ?? [];
        final done = <dynamic>[];

        final sinks = graph.connections
            .where((c) => c.toPortId == '${node.id}_in_process')
            .map   ((c)  => _nodeIdOfPort(c.fromPortId))
            .toSet();

        for (final item in list) {
          _values['${node.id}_item'] = item;

          // expand subgraph
          final sub = <String>{};
          void expand(String nid) {
            if (nid == node.id || !sub.add(nid)) return;
            for (final c in graph.connections
                .where((c) => _nodeIdOfPort(c.toPortId) == nid)) {
              expand(_nodeIdOfPort(c.fromPortId));
            }
            for (final c in graph.connections
                .where((c) => _nodeIdOfPort(c.fromPortId) == nid)) {
              expand(_nodeIdOfPort(c.toPortId));
            }
          }
          sinks.forEach(expand);

          for (final id in sub) {
            _ranInLoop.remove(id);
          }
          for (final n in sorted) {
            if (sub.contains(n.id)) {
              _values[n.id] = await _exec(n);
              _ranInLoop.add(n.id);
            }
          }
          for (final s in sinks) {
            done.add(_values[s]);
          }
        }
        _values[node.id]           = done;
        _values['${node.id}_done'] = done;
        _ranInLoop.add(node.id);

      } else {
        final out = await _exec(node);
        if (out != null) {
          _values[node.id] = out;
          _ranInLoop.add(node.id);
        }
      }
    }
    return _values;
  }

  /// For executors to fetch a connected value.
  dynamic input(Node node, String pin) {
    final toPort = '${node.id}_in_$pin';
    final match  = graph.connections.firstWhere((c) => c.toPortId == toPort);
    final srcId  = _nodeIdOfPort(match.fromPortId);
    final srcPin = match.fromPortId.split('_').last;
    if (srcPin == 'item') return _values['${srcId}_item'];
    return _values[srcId];
  }
}
