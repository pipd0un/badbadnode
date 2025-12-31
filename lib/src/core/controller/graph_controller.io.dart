// lib/src/core/controller/graph_controller.io.dart

part of 'graph_controller.core.dart';

// ───────────────── JSON I/O + Clear (active tab only) ─────────────────

mixin _IOMixin on _GraphCoreBase {
  Map<String, dynamic> toJson() {
    final d = _activeDoc;
    if (d == null) return {'nodes': const [], 'connections': const []};
    return {
      'nodes': d.graph.nodes.values.map((n) => n.toJson()).toList(),
      'connections': d.graph.connections
          .where((c) =>
              d.graph.nodes.containsKey(_nodeIdFromPort(c.fromPortId)) &&
              d.graph.nodes.containsKey(_nodeIdFromPort(c.toPortId)))
          .map((c) => {
                'id': c.id,
                'fromPortId': c.fromPortId,
                'toPortId': c.toPortId,
              })
          .toList(),
    };
  }

  void loadJsonMap(Map<String, dynamic> json) {
    if (!_hasActiveDoc) return;
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
    final d = _activeDoc!;
    d.graph = Graph(nodes: nodes, connections: connections);
    d._rebuildConnectionIndex();
    // Emit events for full reload
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId!));
    for (final n in nodes.values) {
      _hub.fire(NodeAdded(n.id));
    }
    for (final c in connections) {
      _hub.fire(ConnectionAdded(c.fromPortId, c.toPortId));
    }
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
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

  // ───────────────── Helpers for project service ─────────────────

  /// Activate a blueprint by id (public in GraphController). This mixin relies
  /// on GraphController exposing `activateBlueprint(String id)`.
  void activateBlueprint(String id);

  /// Export the graph JSON for the specified blueprint id, preserving active tab.
  Map<String, dynamic> exportJsonForBlueprint(String id) {
    final d = _docs[id];
    if (d == null) return {'nodes': const [], 'connections': const []};
    return {
      'nodes': d.graph.nodes.values.map((n) => n.toJson()).toList(),
      'connections': d.graph.connections
          .where((c) =>
              d.graph.nodes.containsKey(_nodeIdFromPort(c.fromPortId)) &&
              d.graph.nodes.containsKey(_nodeIdFromPort(c.toPortId)))
          .map((c) => {
                'id': c.id,
                'fromPortId': c.fromPortId,
                'toPortId': c.toPortId,
              })
          .toList(),
    };
  }

  /// Import the provided graph JSON into the specified blueprint id.
  void importJsonIntoBlueprint(String id, Map<String, dynamic> json) {
    final d = _docs[id];
    if (d == null) return;
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
    d.graph = Graph(nodes: nodes, connections: connections);
    d._rebuildConnectionIndex();

    // Notify the tab-specific listeners.
    _hub.fire(TabGraphCleared(id));
    _hub.fire(TabGraphChanged(id, d.graph));

    // Also refresh legacy listeners only if this tab is active.
    if (_activeId == id) {
      resetGlobals(); // keep parity with loadJsonMap behavior on active tab
      _hub.fire(GraphCleared());
      _hub.fire(GraphChanged(d.graph));
    }
  }

  // ───────────────── Clear All (active tab only) ─────────────────
  void clear() {
    if (!_hasActiveDoc) return;
    resetGlobals();
    _snapshot();
    final d = _activeDoc!;
    d.graph = gm.clear(d.graph);
    d._rebuildConnectionIndex();
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId!));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }
}
