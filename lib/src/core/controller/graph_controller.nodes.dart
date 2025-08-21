// lib/src/controller/graph_controller.nodes.dart

part of 'graph_controller.core.dart';

// ───────────────── Node CRUD ─────────────────

mixin _NodesMixin on _GraphCoreBase {
  void addNodeOfType(String type, double x, double y) {
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

  @override
  void deleteNode(String id) {
    _snapshot();
    _doc.graph = gm.deleteNode(_doc.graph, id);
    _hub.fire(NodeDeleted(id));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
  }
}
