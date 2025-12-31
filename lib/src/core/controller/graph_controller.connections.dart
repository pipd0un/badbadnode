// lib/src/controller/graph_controller.connections.dart

part of 'graph_controller.core.dart';

// ───────────────── Connections ─────────────────

mixin _ConnectionsMixin on _GraphCoreBase {
  Connection? connectionForInput(String toPortId) =>
      _activeDoc?.connByToPortId[toPortId];

  void addConnection(String from, String to) {
    if (!_hasActiveDoc) return;
    _snapshot();
    // Only one connection per input – remove existing
    final d = _activeDoc!;
    final prev = d.connByToPortId[to];
    if (prev != null) {
      d.graph = gm.deleteConnectionForInput(d.graph, to);
      d.connByToPortId.remove(to);
      d.connById.remove(prev.id);
    }
    final conn = Connection(id: _id(), fromPortId: from, toPortId: to);
    d.graph = gm.addConnection(d.graph, conn);
    d.connByToPortId[to] = conn;
    d.connById[conn.id] = conn;
    _hub.fire(ConnectionAdded(from, to));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  void deleteConnectionForInput(String toPortId) {
    if (!_hasActiveDoc) return;
    _snapshot();
    final d = _activeDoc!;
    final prevConn = d.connByToPortId[toPortId];
    if (prevConn == null) return;
    d.graph = gm.deleteConnectionForInput(d.graph, toPortId);
    d.connByToPortId.remove(toPortId);
    d.connById.remove(prevConn.id);
    _hub.fire(ConnectionDeleted(prevConn.id));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  bool hasConnectionTo(String toPortId) =>
      _activeDoc?.connByToPortId.containsKey(toPortId) ?? false;
}
