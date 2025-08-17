// lib/src/controller/graph_controller.io.dart

part of '../graph_controller.dart';

// ───────────────── JSON I/O + Clear (active tab only) ─────────────────

mixin _IOMixin on _GraphCoreBase {
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
    final jsonMap =
        jsonDecode(utf8.decode(file!.bytes!)) as Map<String, dynamic>;
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
