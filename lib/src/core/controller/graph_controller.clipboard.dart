// lib/src/controller/graph_controller.clipboard.dart

part of 'graph_controller.core.dart';

// ───────────────── Clipboard (shared across tabs) ─────────────────

mixin _ClipboardMixin on _GraphCoreBase {
  List<Node>? _clipNodes;
  List<Connection>? _clipConns;

  void copyNodes(Iterable<String> ids) {
    if (ids.isEmpty) return;
    final d = _activeDoc;
    if (d == null) return;
    _clipNodes = [
      for (final id in ids)
        Node(
          id: id,
          type: d.graph.nodes[id]!.type,
          data: Map<String, dynamic>.from(d.graph.nodes[id]!.data),
        ),
    ];
    _clipConns = d.graph.connections.where((c) {
      final fromNode = _nodeIdFromPort(c.fromPortId);
      final toNode = _nodeIdFromPort(c.toPortId);
      return ids.contains(fromNode) && ids.contains(toNode);
    }).toList();
  }

  void cutNodes(Iterable<String> ids) {
    if (ids.isEmpty) return;
    if (!_hasActiveDoc) return;
    _snapshot();
    copyNodes(ids);
    for (final id in ids) {
      deleteNode(id); // implemented in _NodesMixin
    }
  }

  void pasteClipboard(double dstX, double dstY) {
    if (_clipNodes == null || _clipNodes!.isEmpty) return;
    if (!_hasActiveDoc) return;
    _snapshot();
    // Calculate offset to paste near cursor
    final minX =
        _clipNodes!.map((n) => (n.data['x'] as num).toDouble()).reduce(min);
    final minY =
        _clipNodes!.map((n) => (n.data['y'] as num).toDouble()).reduce(min);
    final dx = dstX - minX;
    final dy = dstY - minY;

    final newIds = <String, String>{};
    final d = _activeDoc!;
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
      d.graph = gm.addNode(d.graph, newNode);
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
      d.graph = gm.addConnection(d.graph, newConn);
      d.connByToPortId[newConn.toPortId] = newConn;
      d.connById[newConn.id] = newConn;
      _hub.fire(ConnectionAdded(newConn.fromPortId, newConn.toPortId));
    }
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }
}
