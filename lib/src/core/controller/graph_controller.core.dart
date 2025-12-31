// lib/src/core/controller/graph_controller.core.dart

library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';

import '../message_hub.dart' show MessageHub;
import '../graph_events.dart';
import '../evaluator.dart' show GraphEvaluator;

import '../../domain/graph.dart';
import '../../domain/graph_mutations.dart' as gm;

import '../../models/connection.dart';
import '../../models/node.dart';

import '../../nodes/builtin_nodes.dart' show registerBuiltInNodes;
import '../../nodes/node_definition.dart'
    show CustomNodeRegistry, NodeDefinition, NodeRegistry;
import '../../services/history_service.dart'
    show GraphHistoryService, GraphSnapshot;

part 'graph_controller.tabs.dart';
part 'graph_controller.history.dart';
part 'graph_controller.globals.dart';
part 'graph_controller.nodes.dart';
part 'graph_controller.connections.dart';
part 'graph_controller.clipboard.dart';
part 'graph_controller.eval.dart';
part 'graph_controller.io.dart';

const double kGridSize = gm.kGridSize;

/// Internal per-blueprint document bundle.
class _Doc {
  Graph graph;
  final GraphHistoryService history;
  final Map<String, dynamic> globals;
  bool globalsBootstrapped;
  String title;
  final Map<String, Node> nodesMut = <String, Node>{};
  final Map<String, Connection> connsById = <String, Connection>{};

  final Map<String, Connection> connByToPortId = <String, Connection>{};
  final Map<String, Connection> connById = <String, Connection>{};
  final Map<String, Set<String>> connIdsByNodeId = <String, Set<String>>{};
  int batchDepth = 0;
  bool batchDirty = false;
  bool batchSnapshotted = false;

  _Doc({required this.graph, required this.title})
      : history = GraphHistoryService(),
        globals = <String, dynamic>{},
        globalsBootstrapped = false {
    history.init(
      Map<String, Node>.unmodifiable(Map.of(graph.nodes)),
      List<Connection>.unmodifiable(graph.connections.toList(growable: false)),
    );
    _rebuildConnectionIndexFrom(graph.connections);
  }

  void _setFromGraph(Graph g) {
    graph = g;
    _rebuildConnectionIndexFrom(g.connections);
  }

  void _stageFromGraph() {
    nodesMut
      ..clear()
      ..addAll(graph.nodes);
    connsById
      ..clear();
    for (final c in graph.connections) {
      connsById[c.id] = c;
    }
    _rebuildConnectionIndexFrom(connsById.values);
  }

  void _materializeGraphFromStage() {
    graph = Graph(
      nodes: Map<String, Node>.unmodifiable(Map.of(nodesMut)),
      connections: List<Connection>.unmodifiable(
        connsById.values.toList(growable: false),
      ),
    );
    _rebuildConnectionIndexFrom(graph.connections);
  }

  void _rebuildConnectionIndexFrom(Iterable<Connection> connections) {
    connByToPortId.clear();
    connById.clear();
    connIdsByNodeId.clear();
    for (final c in connections) {
      _indexAddConnection(c);
    }
  }

  void _indexAddConnection(Connection c) {
    connByToPortId[c.toPortId] = c;
    connById[c.id] = c;
    final fromNodeId = _nodeIdOfPort(c.fromPortId);
    final toNodeId = _nodeIdOfPort(c.toPortId);
    (connIdsByNodeId[fromNodeId] ??= <String>{}).add(c.id);
    (connIdsByNodeId[toNodeId] ??= <String>{}).add(c.id);
  }

  void _indexRemoveConnection(Connection c) {
    connByToPortId.remove(c.toPortId);
    connById.remove(c.id);
    final fromNodeId = _nodeIdOfPort(c.fromPortId);
    final toNodeId = _nodeIdOfPort(c.toPortId);
    final fromSet = connIdsByNodeId[fromNodeId];
    fromSet?.remove(c.id);
    if (fromSet != null && fromSet.isEmpty) connIdsByNodeId.remove(fromNodeId);
    final toSet = connIdsByNodeId[toNodeId];
    toSet?.remove(c.id);
    if (toSet != null && toSet.isEmpty) connIdsByNodeId.remove(toNodeId);
  }

  static String _nodeIdOfPort(String portId) {
    final last = portId.lastIndexOf('_');
    if (last <= 0) return '';
    final secondLast = portId.lastIndexOf('_', last - 1);
    if (secondLast <= 0) return '';
    return portId.substring(0, secondLast);
  }
}

/// Public, read-only descriptor for the tab strip.
class BlueprintTabInfo {
  final String id;
  final String title;
  const BlueprintTabInfo({required this.id, required this.title});
}

/// Base class holding shared state & helpers for mixins.
/// NOTE: Kept private to this library; mixins use `on _GraphCoreBase`.
abstract class _GraphCoreBase {
  // ───────────────── multi-doc state ─────────────────
  final MessageHub _hub = MessageHub();

  final Map<String, _Doc> _docs = {};
  String? _activeId;
  int _bpCounter = 0; // for default names

  _Doc? get _activeDoc =>
      _activeId != null ? _docs[_activeId!] : null;
  bool get _hasActiveDoc => _activeDoc != null;

  /// Seed globals used when no tab is active and copied into newly created tabs.
  final Map<String, dynamic> _seedGlobals = <String, dynamic>{};
  bool _seedGlobalsBootstrapped = false;

  // ───────────────── event stream ─────────────────
  Stream<T> on<T>() => _hub.on<T>();

  // ───────────────── id/helpers ─────────────────
  static final Random _rng = Random();
  static int _seq = 0;

  String _id() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final seq = (_seq = (_seq + 1) & 0xFFFFF);
    final rand = _rng.nextInt(1 << 32);
    return '${now.toRadixString(36)}_${seq.toRadixString(36)}_${rand.toRadixString(36)}';
  }

  String _nodeIdFromPort(String pid) {
    final last = pid.lastIndexOf('_');
    if (last <= 0) return '';
    final secondLast = pid.lastIndexOf('_', last - 1);
    if (secondLast <= 0) return '';
    return pid.substring(0, secondLast);
  }

  // ───────────────── active graph shortcuts ─────────────────
  Graph get graph => _activeDoc?.graph ?? Graph.empty();
  Map<String, Node> get nodes =>
      _activeDoc == null
          ? const <String, Node>{}
          : (_isBatching ? _activeDoc!.nodesMut : _activeDoc!.graph.nodes);
  Iterable<Connection> get connectionValues =>
      _activeDoc == null
          ? const <Connection>[]
          : (_isBatching
              ? _activeDoc!.connsById.values
              : _activeDoc!.graph.connections);
  List<Connection> get connections =>
      _activeDoc == null
          ? const <Connection>[]
          : (_isBatching
              ? _activeDoc!.connsById.values.toList(growable: false)
              : _activeDoc!.graph.connections);

  // ───────────────── history helpers (used across mixins) ─────────────────
  bool get _isBatching => _activeDoc?.batchDepth != null && _activeDoc!.batchDepth > 0;

  void beginBatch() {
    final d = _activeDoc;
    if (d == null) return;
    if (d.batchDepth == 0) {
      d._stageFromGraph();
    }
    d.batchDepth++;
  }

  void endBatch() {
    final d = _activeDoc;
    if (d == null) return;
    if (d.batchDepth == 0) return;
    d.batchDepth--;
    if (d.batchDepth != 0) return;

    if (d.batchDirty) {
      d._materializeGraphFromStage();
      _hub.fire(GraphChanged(d.graph));
      _hub.fire(TabGraphChanged(_activeId!, d.graph));
    }
    d.batchDirty = false;
    d.batchSnapshotted = false;
  }

  T runBatch<T>(T Function() fn) {
    beginBatch();
    try {
      return fn();
    } finally {
      endBatch();
    }
  }

  void _markBatchDirty() {
    final d = _activeDoc;
    if (d == null) return;
    if (!_isBatching) return;
    d.batchDirty = true;
    if (!d.batchSnapshotted) {
      d.batchSnapshotted = true;
      _snapshot();
    }
  }

  void _emitGraphChanged(_Doc d) {
    if (_isBatching) {
      _markBatchDirty();
      return;
    }
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  void _snapshot() {
    final d = _activeDoc;
    if (d == null) return;
    d.history.push(
      d.graph.nodes,
      d.graph.connections,
    );
  }

  void _restoreSnapshot(GraphSnapshot snap) {
    final d = _activeDoc;
    if (d == null) return;
    d._setFromGraph(Graph(nodes: snap.nodes, connections: snap.connections));
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId!));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  // Cross-mixin contracts
  void deleteNode(String id);           // implemented in _NodesMixin
  void resetGlobals();                  // implemented in _GlobalsMixin
}

/// Singleton controller, composed via mixins constrained on _GraphCoreBase.
class GraphController extends _GraphCoreBase
    with
        _TabsMixin,
        _HistoryMixin,
        _GlobalsMixin,
        _NodesMixin,
        _ConnectionsMixin,
        _ClipboardMixin,
        _EvalMixin,
        _IOMixin {
  // ───────────────── singleton ─────────────────
  GraphController._internal() {
    registerBuiltInNodes();
  }
  static final GraphController _inst = GraphController._internal();
  factory GraphController() => _inst;
}
