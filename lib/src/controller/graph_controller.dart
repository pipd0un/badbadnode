// lib/controller/graph_controller.dart
//
// GraphController is now a thin façade around an immutable [Graph] plus
// pure mutation helpers from lib/domain.  It still provides Hub,
// undo/redo, clipboard, JSON I/O, evaluation… but *also* emits a
// [GraphChanged] event after every state change so Riverpod can expose
// a single StateNotifier<Graph>.

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
import '../nodes/node_definition.dart' show CustomNodeRegistry, NodeDefinition, NodeRegistry;
import '../services/history_service.dart' show GraphHistoryService, GraphSnapshot;

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

  final MessageHub _hub = MessageHub();

  // ───────────────── undo / redo stack ─────────────────
  final GraphHistoryService _undoRedo = GraphHistoryService();
  bool get canUndo => _undoRedo.canUndo;
  bool get canRedo => _undoRedo.canRedo;

  void _snapshot() => _undoRedo.push(_state.nodes, _state.connections);

  // Helper to broadcast full-graph change.
  void _emitGraphChanged() => _hub.fire(GraphChanged(_state));

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
    _emitGraphChanged();
  }

  // ───────────────── event helpers ─────────────────
  Stream<T> on<T>() => _hub.on<T>();

  // ───────────────── id helper ─────────────────
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
    _emitGraphChanged();
  }

  void moveNode(String id, double dx, double dy) {
    _state = gm.moveNode(_state, id, dx, dy);
    _hub.fire(NodeMoved(id, dx, dy));
    _emitGraphChanged();
  }

  void snapNodeToGrid(String id) {
    _snapshot();
    _state = gm.snapNode(_state, id);
    _hub.fire(NodeMoved(id, 0, 0));
    _emitGraphChanged();
  }

  void updateNodeData(String id, String key, dynamic value) {
    _snapshot();
    _state = gm.updateNodeData(_state, id, key, value);
    _hub.fire(NodeDataChanged(id));
    _emitGraphChanged();
  }

  void deleteNode(String id) {
    _snapshot();
    _state = gm.deleteNode(_state, id);
    _hub.fire(NodeDeleted(id));
    _emitGraphChanged();
  }

  // ───────────────── Connections ─────────────────
  void addConnection(String from, String to) {
    _snapshot();
    _state = gm.deleteConnectionForInput(_state, to);
    final c = Connection(id: _id(), fromPortId: from, toPortId: to);
    _state = gm.addConnection(_state, c);
    _hub.fire(ConnectionAdded(from, to));
    _emitGraphChanged();
  }

  void deleteConnectionForInput(String toPortId) {
    _snapshot();
    final prev = _state.connections.firstWhere(
        (c) => c.toPortId == toPortId,
        orElse: () => Connection(id: '', fromPortId: '', toPortId: ''));
    _state = gm.deleteConnectionForInput(_state, toPortId);
    if (prev.id.isNotEmpty) _hub.fire(ConnectionDeleted(prev.id));
    _emitGraphChanged();
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
      final f = _nodeIdFromPort(c.fromPortId);
      final t = _nodeIdFromPort(c.toPortId);
      return ids.contains(f) && ids.contains(t);
    }).toList();
  }

  void cutNodes(Iterable<String> ids) {
    _snapshot();
    copyNodes(ids);
    for (final id in ids) {
      deleteNode(id);
    }
  }

  void pasteClipboard(double dstX, double dstY) {
    if (_clipNodes == null || _clipNodes!.isEmpty) return;
    _snapshot();

    final minX = _clipNodes!.map((n) => (n.data['x'] as num).toDouble()).reduce(min);
    final minY = _clipNodes!.map((n) => (n.data['y'] as num).toDouble()).reduce(min);
    final dx = dstX - minX, dy = dstY - minY;

    final idMap = <String, String>{};
    for (final orig in _clipNodes!) {
      final nid = _id();
      idMap[orig.id] = nid;
      final moved = Node(
        id: nid,
        type: orig.type,
        data: {
          ...orig.data,
          'x': (orig.data['x'] as num).toDouble() + dx,
          'y': (orig.data['y'] as num).toDouble() + dy,
        },
      );
      _state = gm.addNode(_state, moved);
      _hub.fire(NodeAdded(nid));
    }

    for (final c in _clipConns ?? []) {
      final oldF = _nodeIdFromPort(c.fromPortId);
      final oldT = _nodeIdFromPort(c.toPortId);
      final newF = idMap[oldF]!;
      final newT = idMap[oldT]!;
      final conn = Connection(
        id: _id(),
        fromPortId: c.fromPortId.replaceFirst(oldF, newF),
        toPortId: c.toPortId.replaceFirst(oldT, newT),
      );
      _state = gm.addConnection(_state, conn);
      _hub.fire(ConnectionAdded(conn.fromPortId, conn.toPortId));
    }
    _emitGraphChanged();
  }

  // ───────────────── Evaluation ─────────────────
  Future<Map<String, dynamic>> evaluate() async => GraphEvaluator(this).run();

  // ───────────────── JSON I/O ─────────────────
  Map<String, dynamic> toJson() => {
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

  void loadJsonMap(Map<String, dynamic> json) {
    _snapshot();
    final nodes = <String, Node>{};
    for (final raw in (json['nodes'] as List<dynamic>)) {
      final n = Node.fromJson(raw as Map<String, dynamic>);
      nodes[n.id] = n;
    }
    final conns = (json['connections'] as List<dynamic>)
        .map((m) => Connection(
              id: m['id'] as String,
              fromPortId: m['fromPortId'] as String,
              toPortId: m['toPortId'] as String,
            ))
        .toList();
    _state = Graph(nodes: nodes, connections: conns);
    _hub.fire(GraphCleared());
    for (final n in nodes.values) {
      _hub.fire(NodeAdded(n.id));
    }
    for (final c in conns) {
      _hub.fire(ConnectionAdded(c.fromPortId, c.toPortId));
    }
    _emitGraphChanged();
  }

  Future<void> loadJsonFromFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final file = res?.files.first;
    if (file?.bytes == null) return;
    loadJsonMap(jsonDecode(utf8.decode(file!.bytes!)) as Map<String, dynamic>);
  }

  // ───────────────── Clear ─────────────────
  void clear() {
    _snapshot();
    _state = gm.clear(_state);
    _hub.fire(GraphCleared());
    _emitGraphChanged();
  }
}
