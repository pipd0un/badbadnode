// lib/src/controller/graph_controller.nodes.dart

part of 'graph_controller.core.dart';

// ───────────────── Node CRUD ─────────────────

mixin _NodesMixin on _GraphCoreBase {
  void addNodeOfType(String type, double x, double y) {
    if (!_hasActiveDoc) return;
    if (_isBatching) {
      _markBatchDirty();
    } else {
      _snapshot();
    }
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
    if (_isBatching) {
      d.nodesMut[id] = node;
    } else {
      d.graph = gm.addNode(d.graph, node);
    }
    _hub.fire(NodeAdded(id));
    _emitGraphChanged(d);
  }

  void moveNode(String id, double dx, double dy) {
    final d = _activeDoc;
    if (d == null) return;
    if (_isBatching) {
      if (dx == 0 && dy == 0) return;
      final n = d.nodesMut[id];
      if (n == null) return;
      final rx = (n.data['x'] as num).toDouble();
      final ry = (n.data['y'] as num).toDouble();
      final nx = rx + dx;
      final ny = ry + dy;
      if (nx == rx && ny == ry) return;
      d.nodesMut[id] = Node(
        id: n.id,
        type: n.type,
        data: {...n.data, 'x': nx, 'y': ny},
      );
    } else {
      d.graph = gm.moveNode(d.graph, id, dx, dy);
    }
    _hub.fire(NodeMoved(id, dx, dy));
    _emitGraphChanged(d);
  }

  void snapNodeToGrid(String id) {
    if (!_hasActiveDoc) return;
    if (_isBatching) {
      _markBatchDirty();
    } else {
      _snapshot();
    }
    final d = _activeDoc!;
    if (_isBatching) {
      final n = d.nodesMut[id];
      if (n == null) return;
      final rx = (n.data['x'] as num).toDouble();
      final ry = (n.data['y'] as num).toDouble();
      final sx = (rx / kGridSize).round() * kGridSize;
      final sy = (ry / kGridSize).round() * kGridSize;
      if (sx == rx && sy == ry) return;
      d.nodesMut[id] = Node(
        id: n.id,
        type: n.type,
        data: {...n.data, 'x': sx, 'y': sy},
      );
    } else {
      d.graph = gm.snapNode(d.graph, id);
    }
    _hub.fire(NodeMoved(id, 0, 0));
    _emitGraphChanged(d);
  }

  void updateNodeData(String id, String key, dynamic value) {
    if (!_hasActiveDoc) return;
    if (_isBatching) {
      _markBatchDirty();
    } else {
      _snapshot();
    }
    final d = _activeDoc!;
    if (_isBatching) {
      final n = d.nodesMut[id];
      if (n == null) return;
      final prev = n.data[key];
      if (prev == value) return;
      d.nodesMut[id] = Node(
        id: n.id,
        type: n.type,
        data: {...n.data, key: value},
      );
    } else {
      d.graph = gm.updateNodeData(d.graph, id, key, value);
    }
    _hub.fire(NodeDataChanged(id));
    _emitGraphChanged(d);
  }

  @override
  void deleteNode(String id) {
    if (!_hasActiveDoc) return;
    if (_isBatching) {
      _markBatchDirty();
    } else {
      _snapshot();
    }
    final d = _activeDoc!;
    if (_isBatching) {
      final connIds = d.connIdsByNodeId[id];
      if (connIds != null && connIds.isNotEmpty) {
        final toRemove = Set<String>.from(connIds);
        for (final cid in toRemove) {
          final c = d.connById[cid];
          if (c != null) {
            d._indexRemoveConnection(c);
            d.connsById.remove(cid);
          }
        }
        d.connIdsByNodeId.remove(id);
      }
      d.nodesMut.remove(id);
    } else {
      final connIds = d.connIdsByNodeId[id];
      final toRemove = connIds == null ? const <String>{} : Set<String>.from(connIds);
      if (toRemove.isNotEmpty) {
        for (final cid in toRemove) {
          final c = d.connById[cid];
          if (c != null) d._indexRemoveConnection(c);
        }
      }
      final nodes = {...d.graph.nodes}..remove(id);
      final connections = toRemove.isEmpty
          ? d.graph.connections
          : [
              for (final c in d.graph.connections)
                if (!toRemove.contains(c.id)) c,
            ];
      d.graph = Graph(nodes: nodes, connections: connections);
    }
    _hub.fire(NodeDeleted(id));
    _emitGraphChanged(d);
  }
}
