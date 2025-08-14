// lib/src/controller/graph_controller.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'dart:developer' as dev;
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

/// Internal per-blueprint document bundle.
class _Doc {
  Graph graph;
  final GraphHistoryService history;
  final Map<String, dynamic> globals;
  bool globalsBootstrapped;
  String title;

  _Doc({required this.graph, required this.title})
      : history = GraphHistoryService(),
        globals = <String, dynamic>{},
        globalsBootstrapped = false {
    history.init(graph.nodes, graph.connections);
  }
}

/// Public, read-only descriptor for the tab strip.
class BlueprintTabInfo {
  final String id;
  final String title;
  const BlueprintTabInfo({required this.id, required this.title});
}

class GraphController {
  // ───────────────── singleton ─────────────────
  GraphController._internal() {
    registerBuiltInNodes();
    // create first blank blueprint
    _openNewBlueprintInternal(
      title: 'Blueprint 1',
      makeActive: true,
      fireEvents: false,
    );
    // announce initial states to any stacked canvases
    _hub.fire(BlueprintOpened(_activeId, _docs[_activeId]!.title));
    _hub.fire(ActiveBlueprintChanged(_activeId));
    _hub.fire(TabGraphChanged(_activeId, _docs[_activeId]!.graph));
    _hub.fire(GraphChanged(_docs[_activeId]!.graph)); // legacy listeners
  }
  static final GraphController _inst = GraphController._internal();
  factory GraphController() => _inst;

  // ───────────────── multi-doc state ─────────────────
  final MessageHub _hub = MessageHub();

  final Map<String, _Doc> _docs = {};
  String _activeId = '';
  int _bpCounter = 1; // for default names

  _Doc get _doc => _docs[_activeId]!;

  // ───────────────── tab API (public) ─────────────────
  List<BlueprintTabInfo> get tabs => [
        for (final e in _docs.entries)
          BlueprintTabInfo(id: e.key, title: e.value.title),
      ];
  String get activeBlueprintId => _activeId;

  /// Lookup the Graph for a specific blueprint id.
  Graph graphOf(String id) => _docs[id]?.graph ?? Graph.empty();

  /// Open a new empty blueprint and activate it.
  String newBlueprint({String? title}) {
    final t =
        title?.trim().isNotEmpty == true ? title!.trim() : 'Blueprint ${++_bpCounter}';
    final sw = Stopwatch()..start();
    final id = _openNewBlueprintInternal(
      title: t,
      makeActive: true,
      fireEvents: true,
    );
    sw.stop();
    dev.log(
      '[perf] GraphController.newBlueprint($id) open+activate=${(sw.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} ms',
      name: 'badbadnode.perf',
    );
    return id;
  }

  /// Close a blueprint tab. If it was active, activates another.
  void closeBlueprint(String id) {
    if (!_docs.containsKey(id)) return;
    final wasActive = id == _activeId;
    _docs.remove(id);
    _hub.fire(BlueprintClosed(id));
    if (_docs.isEmpty) {
      // Always keep one tab around.
      final nid = _openNewBlueprintInternal(
        title: 'Blueprint ${++_bpCounter}',
        makeActive: true,
        fireEvents: true,
      );
      // ensure listeners see an initial state for the new tab
      _hub.fire(TabGraphChanged(nid, _docs[nid]!.graph));
      _hub.fire(GraphChanged(_docs[nid]!.graph)); // legacy
      return;
    }
    if (wasActive) {
      _activeId = _docs.keys.first;
      // Do not fire GraphChanged here – switching tabs shouldn’t rebuild
      // graph-bound widgets unless the graph itself changed.
      _hub.fire(ActiveBlueprintChanged(_activeId));
    }
  }

  /// Switch active blueprint tab.
  void activateBlueprint(String id) {
    if (!_docs.containsKey(id) || id == _activeId) return;
    final sw = Stopwatch()..start();
    _activeId = id;
    _hub.fire(ActiveBlueprintChanged(id));
    sw.stop();
    dev.log(
      '[perf] GraphController.activateBlueprint(${id.substring(0, 6)}…): '
      '${sw.elapsedMicroseconds / 1000.0} ms',
      name: 'badbadnode.perf',
    );
  }

  /// Rename a tab (no IO side-effects).
  void renameBlueprint(String id, String newTitle) {
    final d = _docs[id];
    if (d == null) return;
    d.title = newTitle;
    _hub.fire(BlueprintRenamed(id, newTitle));
  }

  // ───────────────── internal helpers ─────────────────
  String _openNewBlueprintInternal({
    required String title,
    required bool makeActive,
    required bool fireEvents,
  }) {
    final id = _id();
    _docs[id] = _Doc(graph: Graph.empty(), title: title);
    if (makeActive) _activeId = id;
    if (fireEvents) {
      _hub.fire(BlueprintOpened(id, title));
      if (makeActive) _hub.fire(ActiveBlueprintChanged(_activeId));
      // prime stacked canvases for this tab
      _hub.fire(TabGraphChanged(id, _docs[id]!.graph));
      if (makeActive) _hub.fire(GraphChanged(_doc.graph)); // legacy
    }
    return id;
  }

  // ───────────────── event stream ─────────────────
  Stream<T> on<T>() => _hub.on<T>();

  // ───────────────── id helpers ─────────────────
  String _id() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1000)}';

  String _nodeIdFromPort(String pid) {
    final parts = pid.split('_');
    return parts.sublist(0, parts.length - 2).join('_');
  }

  // ───────────────── active graph shortcuts ─────────────────
  Graph get graph => _doc.graph;
  Map<String, Node> get nodes => _doc.graph.nodes;
  List<Connection> get connections => _doc.graph.connections;

  // ───────────────── globals (per tab) ─────────────────
  Map<String, dynamic> get globals => _doc.globals;
  void setGlobal(String k, dynamic v) => _doc.globals[k] = v;
  dynamic getGlobal(String k) => _doc.globals[k];

  bool get globalsBootstrapped => _doc.globalsBootstrapped;
  set globalsBootstrapped(bool v) => _doc.globalsBootstrapped = v;

  /// Reset all global state and mark globals as needing initialization.
  void resetGlobals() {
    _doc.globals.clear();
    _doc.globalsBootstrapped = false;
  }

  // ───────────────── undo / redo stack (per tab) ─────────────────
  bool get canUndo => _doc.history.canUndo;
  bool get canRedo => _doc.history.canRedo;

  void _snapshot() => _doc.history.push(_doc.graph.nodes, _doc.graph.connections);

  void undo() {
    if (!canUndo) return;
    _restoreSnapshot(_doc.history.undo());
  }

  void redo() {
    if (!canRedo) return;
    _restoreSnapshot(_doc.history.redo());
  }

  void _restoreSnapshot(GraphSnapshot snap) {
    _doc.graph = Graph(nodes: snap.nodes, connections: snap.connections);
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  // ───────────────── Node CRUD ─────────────────
  void addNodeOfType(String type, double x, double y) {
    _snapshot();
    final id = _id();
    NodeDefinition? def =
        NodeRegistry().lookup(type) ?? CustomNodeRegistry().all[type];
    if (def == null) throw ArgumentError('Unknown node type "$type"');

    final node = Node(
      id: id,
      type: type,
      data: {
        'x': x,
        'y': y,
        'inputs': List<String>.from(def.inputs),
        'outputs': List<String>.from(def.outputs),
        ...def.initialData,
      },
    );
    _doc.graph = gm.addNode(_doc.graph, node);
    _hub.fire(NodeAdded(id));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  void moveNode(String id, double dx, double dy) {
    _doc.graph = gm.moveNode(_doc.graph, id, dx, dy);
    _hub.fire(NodeMoved(id, dx, dy));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  void snapNodeToGrid(String id) {
    _snapshot();
    _doc.graph = gm.snapNode(_doc.graph, id);
    _hub.fire(NodeMoved(id, 0, 0));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  void updateNodeData(String id, String key, dynamic value) {
    _snapshot();
    _doc.graph = gm.updateNodeData(_doc.graph, id, key, value);
    _hub.fire(NodeDataChanged(id));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  void deleteNode(String id) {
    _snapshot();
    _doc.graph = gm.deleteNode(_doc.graph, id);
    _hub.fire(NodeDeleted(id));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  // ───────────────── Connections ─────────────────
  void addConnection(String from, String to) {
    _snapshot();
    // Only one connection per input – remove existing
    _doc.graph = gm.deleteConnectionForInput(_doc.graph, to);
    final conn = Connection(id: _id(), fromPortId: from, toPortId: to);
    _doc.graph = gm.addConnection(_doc.graph, conn);
    _hub.fire(ConnectionAdded(from, to));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  void deleteConnectionForInput(String toPortId) {
    _snapshot();
    final prevConn = _doc.graph.connections.firstWhere(
      (c) => c.toPortId == toPortId,
      orElse: () => Connection(id: '', fromPortId: '', toPortId: ''),
    );
    _doc.graph = gm.deleteConnectionForInput(_doc.graph, toPortId);
    if (prevConn.id.isNotEmpty) {
      _hub.fire(ConnectionDeleted(prevConn.id));
    }
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  bool hasConnectionTo(String toPortId) =>
      _doc.graph.connections.any((c) => c.toPortId == toPortId);

  // ───────────────── Clipboard (shared across tabs) ─────────────────
  List<Node>? _clipNodes;
  List<Connection>? _clipConns;

  void copyNodes(Iterable<String> ids) {
    if (ids.isEmpty) return;
    _clipNodes = [
      for (final id in ids)
        Node(
          id: id,
          type: _doc.graph.nodes[id]!.type,
          data: Map<String, dynamic>.from(_doc.graph.nodes[id]!.data),
        ),
    ];
    _clipConns = _doc.graph.connections.where((c) {
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
      _doc.graph = gm.addNode(_doc.graph, newNode);
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
      _doc.graph = gm.addConnection(_doc.graph, newConn);
      _hub.fire(ConnectionAdded(newConn.fromPortId, newConn.toPortId));
    }
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  // ───────────────── Evaluation (active tab only) ─────────────────
  Future<Map<String, dynamic>> evaluate() async {
    return GraphEvaluator(this).run();
  }

  Future<Map<String, dynamic>> evaluateFrom(String nodeId) async {
    return GraphEvaluator(this).evaluateFrom(nodeId);
  }

  // ───────────────── JSON I/O (active tab only) ─────────────────
  Map<String, dynamic> toJson() {
    return {
      'nodes': _doc.graph.nodes.values.map((n) => n.toJson()).toList(),
      'connections': _doc.graph.connections
          .where((c) =>
              _doc.graph.nodes.containsKey(_nodeIdFromPort(c.fromPortId)) &&
              _doc.graph.nodes.containsKey(_nodeIdFromPort(c.toPortId)))
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
        .map(
          (m) => Connection(
            id: m['id'] as String,
            fromPortId: m['fromPortId'] as String,
            toPortId: m['toPortId'] as String,
          ),
        )
        .toList();
    _doc.graph = Graph(nodes: nodes, connections: connections);
    // Emit events for full reload
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId));
    for (final n in nodes.values) {
      _hub.fire(NodeAdded(n.id));
    }
    for (final c in connections) {
      _hub.fire(ConnectionAdded(c.fromPortId, c.toPortId));
    }
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }

  Future<void> loadJsonFromFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final file = res?.files.first;
    if (file?.bytes == null) return;
    final jsonMap = jsonDecode(utf8.decode(file!.bytes!)) as Map<String, dynamic>;
    loadJsonMap(jsonMap);
  }

  // ───────────────── Clear All (active tab only) ─────────────────
  void clear() {
    resetGlobals();
    _snapshot();
    _doc.graph = gm.clear(_doc.graph);
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }
}
