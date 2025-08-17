// lib/src/controller/graph_controller.connections.dart

part of '../graph_controller.dart';

// ───────────────── Connections ─────────────────

mixin _ConnectionsMixin on _GraphCoreBase {
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
}
