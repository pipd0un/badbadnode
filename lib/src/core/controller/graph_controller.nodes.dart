// lib/src/controller/graph_controller.nodes.dart

part of 'graph_controller.core.dart';

// ───────────────── Node CRUD ─────────────────

mixin _NodesMixin on _GraphCoreBase {
  void addNodeOfType(String type, double x, double y) {
    if (!_hasActiveDoc) return;
    _snapshot();
    final id = _id();
    NodeDefinition? def =
        NodeRegistry().lookup(type) ?? CustomNodeRegistry().all[type];
    if (def == null) {
      throw ArgumentError('Unknown node type "$type"');
    }

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
    final d = _activeDoc!;
    d.graph = gm.addNode(d.graph, node);
    _hub.fire(NodeAdded(id));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  void moveNode(String id, double dx, double dy) {
    final d = _activeDoc;
    if (d == null) return;
    d.graph = gm.moveNode(d.graph, id, dx, dy);
    _hub.fire(NodeMoved(id, dx, dy));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  void snapNodeToGrid(String id) {
    if (!_hasActiveDoc) return;
    _snapshot();
    final d = _activeDoc!;
    d.graph = gm.snapNode(d.graph, id);
    _hub.fire(NodeMoved(id, 0, 0));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  void updateNodeData(String id, String key, dynamic value) {
    if (!_hasActiveDoc) return;
    _snapshot();
    final d = _activeDoc!;
    d.graph = gm.updateNodeData(d.graph, id, key, value);
    _hub.fire(NodeDataChanged(id));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  @override
  void deleteNode(String id) {
    if (!_hasActiveDoc) return;
    _snapshot();
    final d = _activeDoc!;
    d.graph = gm.deleteNode(d.graph, id);
    _hub.fire(NodeDeleted(id));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }
}
