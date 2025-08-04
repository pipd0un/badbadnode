// lib/core/evaluator.dart
import 'dart:async';

import '../controller/graph_controller.dart';
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

  // ───────── helpers ─────────
  String _nodeIdOfPort(String pid) {
    final parts = pid.split('_');
    return parts.sublist(0, parts.length - 2).join('_');
  }

  /// Public helper – nodes & plugins call this.
  String nodeIdOfPort(String portId) => _nodeIdOfPort(portId);

  NodeDefinition _def(String type) =>
      NodeRegistry().lookup(type) ??
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
    final nodes = graph.nodes.values.toList();
    final deps = <String, Set<String>>{for (final n in nodes) n.id: <String>{}};

    for (final c in graph.connections) {
      if (c.toPortId.contains('_in_process') ||
          c.toPortId.contains('_in_action')) {
        continue;
      }
      final from = _nodeIdOfPort(c.fromPortId);
      final to   = _nodeIdOfPort(c.toPortId);
      deps[to]!.add(from);
    }

    final visited = <String>{};
    final result  = <Node>[];
    void dfs(String id) {
      if (!visited.add(id)) return;
      for (final d in deps[id]!) {
        dfs(d);
      }
      final n = graph.nodes[id];
      if (n != null) result.add(n);
    }
    for (final id in deps.keys) {
      dfs(id);
    }
    return result;
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

    // collect reachable nodes (skip _in_process / _in_action links)
    final needed = <String>{};
    void crawl(String id) {
      if (!needed.add(id)) return;
      for (final c in graph.connections) {
        bool blocked(String p) =>
            p.contains('_in_process') || p.contains('_in_action');
        if (blocked(c.fromPortId) || blocked(c.toPortId)) continue;
        final f = _nodeIdOfPort(c.fromPortId);
        final t = _nodeIdOfPort(c.toPortId);
        if (f == id) crawl(t);
        if (t == id) crawl(f);
      }
    }
    crawl(rootId);

    final executedCmd = <String>{};
    final topo = _topoSort();

    // 1️⃣ DATA pass (needed only)
    for (final n in topo) {
      if (!needed.contains(n.id) || _def(n.type).isCommand) continue;

      if (n.type == 'if') {
        final cond = input(n, 'bool') as bool? ?? false;
        _values[n.id] =
            await _exec(n, overrideInput: cond ? 'true' : 'false');
        continue;
      }
      if (n.type == 'loop') {
        await _runLoop(n, executedCmd, neededFilter: needed);
        continue;
      }
      final out = await _exec(n);
      if (out != null) _values[n.id] = out;
    }

    // 2️⃣ COMMAND pass (needed only)
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
    Set<String> executedCmd,           // ← global “already done” set
    {Set<String>? neededFilter}
  ) async {
    final list = input(loop, 'in') as List<dynamic>? ?? [];
    final done = <dynamic>[];

    // 1. find sink nodes that anchor the body
    final sinks = graph.connections
        .where((c) => c.toPortId == '${loop.id}_in_process')
        .map((c) => _nodeIdOfPort(c.fromPortId))
        .where((id) => neededFilter == null || neededFilter.contains(id))
        .toSet();

    // Keep track of every command that appears in the body,
    // so we can skip it later in the global pass.
    final cmdsSeenInBody = <String>{};

    for (final item in list) {
      _values['${loop.id}_item'] = item;

      /* build body set */
      final body = <String>{};
      void expand(String id) {
        if (!body.add(id) || id == loop.id) return;
        for (final c in graph.connections
            .where((c) => _nodeIdOfPort(c.toPortId) == id)) {
          expand(_nodeIdOfPort(c.fromPortId));
        }
        for (final c in graph.connections
            .where((c) => _nodeIdOfPort(c.fromPortId) == id)) {
          expand(_nodeIdOfPort(c.toPortId));
        }
      }
      sinks.forEach(expand);

      /* order the body topologically */
      final ordered =
          _topoSort().where((n) => body.contains(n.id)).toList();

      /* DATA pass inside the loop */
      for (final n in ordered) {
        if (neededFilter != null && !neededFilter.contains(n.id)) continue;
        if (_def(n.type).isCommand) continue;

        if (n.type == 'if') {
          final cond = input(n, 'bool') as bool? ?? false;
          _values[n.id] =
              await _exec(n, overrideInput: cond ? 'true' : 'false');
        } else {
          final out = await _exec(n);
          if (out != null) _values[n.id] = out;
        }
      }

      /* COMMAND pass inside the loop – run every time */
      for (final n in ordered) {
        if (!_def(n.type).isCommand) continue;
        cmdsSeenInBody.add(n.id);          // remember it
        await _exec(n);                    // ALWAYS run each iteration
      }

      /* collect sink values */
      for (final s in sinks) {
        done.add(_values[s]);
      }
    }

    /* ensure global pass skips these commands */
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
