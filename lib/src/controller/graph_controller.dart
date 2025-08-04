// lib/controller/graph_controller.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';

import '../core/message_hub.dart' show MessageHub;
import '../core/graph_events.dart';
import '../core/evaluator.dart' show GraphEvaluator;

import '../domain/graph.dart';
import '../domain/graph_mutations.dart' as gm;

import '../models/connection.dart';
import '../models/node.dart';

import '../nodes/builtin_nodes.dart' show registerBuiltInNodes;
import '../nodes/node_definition.dart'
    show CustomNodeRegistry, NodeDefinition, NodeRegistry;
import '../services/history_service.dart'
    show GraphHistoryService, GraphSnapshot;

const double kGridSize = gm.kGridSize;

class GraphController {
  // ───────────────── singleton ─────────────────
  GraphController._internal() {
    registerBuiltInNodes();
    _undoRedo.init(_state.nodes, _state.connections);
  }
  static final GraphController _inst = GraphController._internal();
  factory GraphController() => _inst;

  // ───────────────── internal state ─────────────────
  Graph _state = Graph.empty();
  Graph get graph => _state;
  Map<String, Node> get nodes => _state.nodes;
  List<Connection> get connections => _state.connections;
  final Map<String, dynamic> _globals = {};

  bool _globalsBootstrapped = false;
  // ignore: unnecessary_getters_setters
  bool get globalsBootstrapped => _globalsBootstrapped;
  set globalsBootstrapped(bool v) => _globalsBootstrapped = v;

  Map<String, dynamic> get globals => _globals;
  void setGlobal(String k, dynamic v) => _globals[k] = v;
  dynamic getGlobal(String k) => _globals[k];

  /// Reset all global state and mark globals as needing initialization.
  void resetGlobals() {
    _globals.clear();
    _globalsBootstrapped = false;
  }

  final MessageHub _hub = MessageHub();

  // ───────────────── undo / redo stack ─────────────────
  final GraphHistoryService _undoRedo = GraphHistoryService();
  bool get canUndo => _undoRedo.canUndo;
  bool get canRedo => _undoRedo.canRedo;

  void _snapshot() => _undoRedo.push(_state.nodes, _state.connections);

  void undo() {
    if (!canUndo) return;
    _restoreSnapshot(_undoRedo.undo());
  }

  void redo() {
    if (!canRedo) return;
    _restoreSnapshot(_undoRedo.redo());
  }

  void _restoreSnapshot(GraphSnapshot snap) {
    _state = Graph(nodes: snap.nodes, connections: snap.connections);
    _hub.fire(GraphCleared());
    for (final n in _state.nodes.values) {
      _hub.fire(NodeAdded(n.id));
    }
    for (final c in _state.connections) {
      _hub.fire(ConnectionAdded(c.fromPortId, c.toPortId));
    }
    _hub.fire(GraphChanged(_state));
  }

  // ───────────────── event stream ─────────────────
  Stream<T> on<T>() => _hub.on<T>();

  // ───────────────── id helpers ─────────────────
  String _id() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1000)}';

  String _nodeIdFromPort(String pid) {
    final match = RegExp(r'^(.+)_([^_]+)_([^_]+)$').firstMatch(pid);
    if (match == null) throw FormatException('Invalid portId: $pid');
    return match.group(1)!;
  }

  // ───────────────── Node CRUD ─────────────────
  void addNodeOfType(String type, double x, double y) {
    _snapshot();
    final id  = _id();
    NodeDefinition? def = NodeRegistry().lookup(type) ?? CustomNodeRegistry().all[type];
    if (def == null) throw ArgumentError('Unknown node type "$type"');

    final node = Node(
      id: id,
      type: type,
      data: {
        'x': x,
        'y': y,
        'inputs' : List<String>.from(def.inputs),
        'outputs': List<String>.from(def.outputs),
        ...def.initialData,
      },
    );
    _state = gm.addNode(_state, node);
    _hub.fire(NodeAdded(id));
    _hub.fire(GraphChanged(_state));
  }

  void moveNode(String id, double dx, double dy) {
    _state = gm.moveNode(_state, id, dx, dy);
    _hub.fire(NodeMoved(id, dx, dy));
    _hub.fire(GraphChanged(_state));
  }

  void snapNodeToGrid(String id) {
    _snapshot();
    _state = gm.snapNode(_state, id);
    _hub.fire(NodeMoved(id, 0, 0));
    _hub.fire(GraphChanged(_state));
  }

  void updateNodeData(String id, String key, dynamic value) {
    _snapshot();
    _state = gm.updateNodeData(_state, id, key, value);
    _hub.fire(NodeDataChanged(id));
    _hub.fire(GraphChanged(_state));
  }

  void deleteNode(String id) {
    _snapshot();
    _state = gm.deleteNode(_state, id);
    _hub.fire(NodeDeleted(id));
    _hub.fire(GraphChanged(_state));
  }

  // ───────────────── Connections ─────────────────
  void addConnection(String from, String to) {
    _snapshot();
    // Only one connection per input – remove existing
    _state = gm.deleteConnectionForInput(_state, to);
    final conn = Connection(id: _id(), fromPortId: from, toPortId: to);
    _state = gm.addConnection(_state, conn);
    _hub.fire(ConnectionAdded(from, to));
    _hub.fire(GraphChanged(_state));
  }

  void deleteConnectionForInput(String toPortId) {
    _snapshot();
    final prevConn = _state.connections.firstWhere(
      (c) => c.toPortId == toPortId,
      orElse: () => Connection(id: '', fromPortId: '', toPortId: ''),
    );
    _state = gm.deleteConnectionForInput(_state, toPortId);
    if (prevConn.id.isNotEmpty) {
      _hub.fire(ConnectionDeleted(prevConn.id));
    }
    _hub.fire(GraphChanged(_state));
  }

  bool hasConnectionTo(String toPortId) =>
      _state.connections.any((c) => c.toPortId == toPortId);

  // ───────────────── Clipboard ─────────────────
  List<Node>? _clipNodes;
  List<Connection>? _clipConns;

  void copyNodes(Iterable<String> ids) {
    if (ids.isEmpty) return;
    _clipNodes = [
      for (final id in ids)
        Node(
          id: id,
          type: _state.nodes[id]!.type,
          data: Map<String, dynamic>.from(_state.nodes[id]!.data),
        )
    ];
    _clipConns = _state.connections.where((c) {
      final fromNode = _nodeIdFromPort(c.fromPortId);
      final toNode = _nodeIdFromPort(c.toPortId);
      return ids.contains(fromNode) && ids.contains(toNode);
    }).toList();
  }

  void cutNodes(Iterable<String> ids) {
    if (ids.isEmpty) return;
    _snapshot();
    copyNodes(ids);
    for (final id in ids) {
      deleteNode(id);
    }
  }

  void pasteClipboard(double dstX, double dstY) {
    if (_clipNodes == null || _clipNodes!.isEmpty) return;
    _snapshot();
    // Calculate offset to paste near cursor
    final minX = _clipNodes!.map((n) => (n.data['x'] as num).toDouble()).reduce(min);
    final minY = _clipNodes!.map((n) => (n.data['y'] as num).toDouble()).reduce(min);
    final dx = dstX - minX;
    final dy = dstY - minY;

    final newIds = <String, String>{};
    for (final orig in _clipNodes!) {
      final nid = _id();
      newIds[orig.id] = nid;
      final newNode = Node(
        id: nid,
        type: orig.type,
        data: {
          ...orig.data,
          'x': (orig.data['x'] as num).toDouble() + dx,
          'y': (orig.data['y'] as num).toDouble() + dy,
        },
      );
      _state = gm.addNode(_state, newNode);
      _hub.fire(NodeAdded(nid));
    }
    // Recreate connections between pasted nodes
    for (final c in _clipConns ?? []) {
      final oldFrom = _nodeIdFromPort(c.fromPortId);
      final oldTo = _nodeIdFromPort(c.toPortId);
      if (!newIds.containsKey(oldFrom) || !newIds.containsKey(oldTo)) continue;
      final newConn = Connection(
        id: _id(),
        fromPortId: c.fromPortId.replaceFirst(oldFrom, newIds[oldFrom]!),
        toPortId: c.toPortId.replaceFirst(oldTo, newIds[oldTo]!),
      );
      _state = gm.addConnection(_state, newConn);
      _hub.fire(ConnectionAdded(newConn.fromPortId, newConn.toPortId));
    }
    _hub.fire(GraphChanged(_state));
  }

  // ───────────────── Evaluation ─────────────────
  Future<Map<String, dynamic>> evaluate() async {
    return GraphEvaluator(this).run();
  }

  Future<Map<String, dynamic>> evaluateFrom(String nodeId) async {
    return GraphEvaluator(this).evaluateFrom(nodeId);
  }

  // ───────────────── JSON I/O ─────────────────
  Map<String, dynamic> toJson() {
    return {
      'nodes': _state.nodes.values.map((n) => n.toJson()).toList(),
      'connections': _state.connections
          .where((c) =>
              _state.nodes.containsKey(_nodeIdFromPort(c.fromPortId)) &&
              _state.nodes.containsKey(_nodeIdFromPort(c.toPortId)))
          .map((c) => {
                'id': c.id,
                'fromPortId': c.fromPortId,
                'toPortId': c.toPortId,
              })
          .toList(),
    };
  }

  void loadJsonMap(Map<String, dynamic> json) {
    _snapshot();
    resetGlobals(); // ensure fresh globals for new graph
    // Rebuild nodes and connections from JSON
    final Map<String, Node> nodes = {};
    for (final raw in (json['nodes'] as List<dynamic>)) {
      final node = Node.fromJson(raw as Map<String, dynamic>);
      nodes[node.id] = node;
    }
    final connections = (json['connections'] as List<dynamic>)
        .map((m) => Connection(
              id: m['id'] as String,
              fromPortId: m['fromPortId'] as String,
              toPortId: m['toPortId'] as String,
            ))
        .toList();
    _state = Graph(nodes: nodes, connections: connections);
    // Emit events for full reload
    _hub.fire(GraphCleared());
    for (final n in nodes.values) {
      _hub.fire(NodeAdded(n.id));
    }
    for (final c in connections) {
      _hub.fire(ConnectionAdded(c.fromPortId, c.toPortId));
    }
    _hub.fire(GraphChanged(_state));
  }

  Future<void> loadJsonFromFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final file = res?.files.first;
    if (file?.bytes == null) return;
    final jsonMap =
        jsonDecode(utf8.decode(file!.bytes!)) as Map<String, dynamic>;
    loadJsonMap(jsonMap);
  }

  // ───────────────── Clear All ─────────────────
  void clear() {
    resetGlobals();
    _snapshot();
    _state = gm.clear(_state);
    _hub.fire(GraphCleared());
    _hub.fire(GraphChanged(_state));
  }
}
