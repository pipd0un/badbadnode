// lib/core/evaluator.dart
import 'dart:async';
import 'dart:collection' show Queue;

import 'graph_controller.dart';
import '../models/node.dart';
import '../models/connection.dart';
import '../nodes/node_definition.dart' show NodeDefinition, NodeRegistry;

/// Runtime callback signature for every node type.
typedef NodeExecutor = Future<dynamic> Function(Node node, GraphEvaluator ev);

class GraphEvaluator {
  GraphEvaluator(this.graph);

  // ───────────────────────────────────────────────────────────────
  final GraphController graph;
  final Map<String, dynamic> _values = {};
  final Set<String> _ranInLoop = {};

  Map<String, dynamic> get _globals => graph.globals;
  void setObject(String k, dynamic v) => _globals[k] = v;
  dynamic getObject(String k) => _globals[k];

  // inside GraphEvaluator
  final Map<String, NodeDefinition> _defCache = {};
  List<Node>? _topoCache;
  Map<String, List<String>>? _fwd, _rev;

  void _buildAdjacency() {
    if (_fwd != null) return;
    _fwd = {};
    _rev = {};
    for (final c in graph.connections) {
      if (c.toPortId.contains('_in_process') || c.toPortId.contains('_in_action')) {
        continue;
      }
      final f = _nodeIdOfPort(c.fromPortId);
      final t = _nodeIdOfPort(c.toPortId);
      (_fwd![f] ??= <String>[]).add(t);
      (_rev![t] ??= <String>[]).add(f);
    }
  }

  // ───────── helpers ─────────
  String _nodeIdOfPort(String pid) {
    final parts = pid.split('_');
    return parts.sublist(0, parts.length - 2).join('_');
  }

  /// Public helper – nodes & plugins call this.
  String nodeIdOfPort(String portId) => _nodeIdOfPort(portId);

  NodeDefinition _def(String type) =>
    _defCache[type] ??= NodeRegistry().lookup(type) ??
    (throw Exception('No node definition for "$type"'));

  Future<dynamic> _exec(Node node, {String? overrideInput}) {
    final def = _def(node.type);
    if (overrideInput != null) {
      final data = {...node.data, 'activeInput': overrideInput};
      return def.run(Node(id: node.id, type: node.type, data: data), this);
    }
    return def.run(node, this);
  }

  /*───────────────────── TOPOLOGICAL ORDER ─────────────────────*/
  List<Node> _topoSort() {
    if (_topoCache != null) return _topoCache!;
    _buildAdjacency();

    final ids = graph.nodes.keys.toList();
    final inDeg = <String, int>{ for (final id in ids) id: (_rev![id]?.length ?? 0) };
    final q = Queue<String>()..addAll(ids.where((id) => inDeg[id] == 0));
    final orderedIds = <String>[];

    while (q.isNotEmpty) {
      final u = q.removeFirst();
      orderedIds.add(u);
      for (final v in _fwd![u] ?? const <String>[]) {
        final nv = inDeg[v]! - 1; // read
        inDeg[v] = nv;            // write back
        if (nv == 0) q.add(v);    // enqueue when in-degree hits zero
      }
    }

    // In case of cycles, append remaining nodes to keep stable behavior.
    if (orderedIds.length < ids.length) {
      for (final id in ids) {
        if (!orderedIds.contains(id)) orderedIds.add(id);
      }
    }

    _topoCache = [for (final id in orderedIds) graph.nodes[id]!];
    return _topoCache!;
  }

  /*────────────────── GLOBAL BOOTSTRAP ───────────────────────*/
  Future<void> _ensureGlobals() async {
    if (graph.globalsBootstrapped) return;

    // 1️⃣  collect: initialisers + all upstream DATA nodes
    final needed = <String>{};
    void addUpstream(String id) {
      if (!needed.add(id)) return;
      for (final c in graph.connections.where(
          (c) => _nodeIdOfPort(c.toPortId) == id)) {
        final upId = _nodeIdOfPort(c.fromPortId);
        if (_def(graph.nodes[upId]!.type).isCommand) continue; // skip side-effects
        addUpstream(upId);
      }
    }

    for (final n in graph.nodes.values) {
      if (_def(n.type).isInitializer) addUpstream(n.id);
    }

    // 2️⃣  evaluate that subset once, in topo order
    final topo = _topoSort();
    for (final n in topo) {
      if (!needed.contains(n.id)) continue;
      if (_def(n.type).isCommand) continue; // should already be excluded
      dynamic out;
      if (n.type == 'if') {
        final cond = input(n, 'bool') as bool? ?? false;
        out = await _exec(n, overrideInput: cond ? 'true' : 'false');
      } else {
        out = await _exec(n);
      }
      if (out != null) _values[n.id] = out;
    }

    // 3️⃣  scratch values no longer needed
    _values.clear();
    graph.globalsBootstrapped = true;
  }


  /*──────────────────── FULL GRAPH RUN ───────────────────────*/
  Future<Map<String, dynamic>> run() async {
    _values.clear();
    _ranInLoop.clear();
    await _ensureGlobals();

    final executedCmd = <String>{};
    final topo = _topoSort();

    // 1️⃣ DATA pass
    for (final n in topo) {
      if (_def(n.type).isCommand) continue;

      if (n.type == 'if') {
        final cond = input(n, 'bool') as bool? ?? false;
        _values[n.id] =
            await _exec(n, overrideInput: cond ? 'true' : 'false');
        continue;
      }
      if (n.type == 'loop') {
        await _runLoop(n, executedCmd);
        continue;
      }
      final out = await _exec(n);
      if (out != null) _values[n.id] = out;
    }

    // 2️⃣ COMMAND pass
    for (final n in topo) {
      if (!_def(n.type).isCommand) continue;
      if (executedCmd.contains(n.id)) continue;
      if (!_reachable(n)) continue;
      await _exec(n);
    }

    return _values;
  }

  /*────────────── PARTIAL SUB-GRAPH RUN ───────────────*/
  Future<Map<String, dynamic>> evaluateFrom(String rootId) async {
    _values.clear();
    _ranInLoop.clear();
    await _ensureGlobals();
    _buildAdjacency();

    final needed = <String>{};
    final q = Queue<String>()..add(rootId);
    while (q.isNotEmpty) {
      final id = q.removeFirst();
      if (!needed.add(id)) continue;
      for (final up in _rev![id] ?? const <String>[]) {
        q.add(up);
      }
      for (final dn in _fwd![id] ?? const <String>[]) {
        q.add(dn);
      }
    }

    final executedCmd = <String>{};
    final topo = _topoSort();

    // DATA pass
    for (final n in topo) {
      if (!needed.contains(n.id) || _def(n.type).isCommand) continue;
      if (n.type == 'if') {
        final cond = input(n, 'bool') as bool? ?? false;
        _values[n.id] = await _exec(n, overrideInput: cond ? 'true' : 'false');
      } else if (n.type == 'loop') {
        await _runLoop(n, executedCmd, neededFilter: needed);
      } else {
        final out = await _exec(n);
        if (out != null) _values[n.id] = out;
      }
    }

    // COMMAND pass
    for (final n in topo) {
      if (!needed.contains(n.id)) continue;
      if (!_def(n.type).isCommand) continue;
      if (executedCmd.contains(n.id)) continue;
      if (!_reachable(n, neededFilter: needed)) continue;
      await _exec(n);
    }

    return _values;
  }

  /*────────────────────  LOOP helper  ──────────────────────*/
  Future<void> _runLoop(
  Node loop,
  Set<String> executedCmd, {Set<String>? neededFilter}
) async {
  final list = input(loop, 'in') as List<dynamic>? ?? [];

  // sinks once
  final sinks = graph.connections
      .where((c) => c.toPortId == '${loop.id}_in_process')
      .map((c) => _nodeIdOfPort(c.fromPortId))
      .where((id) => neededFilter == null || neededFilter.contains(id))
      .toSet();

  // build the loop body set once (topological order filtered once)
  final body = <String>{};
  void expand(String id) {
    if (!body.add(id) || id == loop.id) return;
    for (final up in graph.connections.where((c) => _nodeIdOfPort(c.toPortId) == id)) {
      expand(_nodeIdOfPort(up.fromPortId));
    }
    for (final dn in graph.connections.where((c) => _nodeIdOfPort(c.fromPortId) == id)) {
      expand(_nodeIdOfPort(dn.toPortId));
    }
  }
  sinks.forEach(expand);

  final ordered = _topoSort().where((n) => body.contains(n.id)).toList();
  final cmdsSeenInBody = <String>{};
  final done = <dynamic>[];

  for (final item in list) {
    _values['${loop.id}_item'] = item;

    // DATA inside loop
    for (final n in ordered) {
      if (neededFilter != null && !neededFilter.contains(n.id)) continue;
      if (_def(n.type).isCommand) continue;
      if (n.type == 'if') {
        final cond = input(n, 'bool') as bool? ?? false;
        _values[n.id] = await _exec(n, overrideInput: cond ? 'true' : 'false');
      } else {
        final out = await _exec(n);
        if (out != null) _values[n.id] = out;
      }
    }

    // COMMAND inside loop (every iteration)
    for (final n in ordered) {
      if (!_def(n.type).isCommand) continue;
      cmdsSeenInBody.add(n.id);
      await _exec(n);
    }

    // collect sink values
    for (final s in sinks) {
      done.add(_values[s]);
    }
  }

  executedCmd.addAll(cmdsSeenInBody);
  _values[loop.id] = done;
  _values['${loop.id}_done'] = done;
}


  /*──────────────── reachability check ─────────────────────*/
  bool _reachable(Node n, {Set<String>? neededFilter}) {
    return graph.connections.any((c) {
      if (_nodeIdOfPort(c.toPortId) != n.id) return false;
      final src = _nodeIdOfPort(c.fromPortId);
      return (neededFilter == null || neededFilter.contains(src)) &&
          _values.containsKey(src);
    });
  }

  /*────────────────────────  input()  ───────────────────────*/
  dynamic input(Node node, String pin) {
    final pid = '${node.id}_in_$pin';
    final conn = graph.connections.firstWhere(
      (c) => c.toPortId == pid,
      orElse: () => Connection(id: '', fromPortId: '', toPortId: ''),
    );
    if (conn.id.isEmpty) return null;
    final srcId  = _nodeIdOfPort(conn.fromPortId);
    final srcPin = conn.fromPortId.split('_').last;
    return srcPin == 'item' ? _values['${srcId}_item'] : _values[srcId];
  }
}
