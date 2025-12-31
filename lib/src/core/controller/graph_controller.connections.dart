// lib/src/controller/graph_controller.connections.dart

part of 'graph_controller.core.dart';

// ───────────────── Connections ─────────────────

mixin _ConnectionsMixin on _GraphCoreBase {
  Connection? connectionForInput(String toPortId) =>
      _activeDoc?.connByToPortId[toPortId];

  void addConnection(String from, String to) {
    if (!_hasActiveDoc) return;
    if (_isBatching) {
      _markBatchDirty();
    } else {
      _snapshot();
    }
    // Only one connection per input – remove existing
    final d = _activeDoc!;
    final conn = Connection(id: _id(), fromPortId: from, toPortId: to);
    if (_isBatching) {
      final prev = d.connByToPortId[to];
      if (prev != null) {
        d._indexRemoveConnection(prev);
        d.connsById.remove(prev.id);
      }
      d.connsById[conn.id] = conn;
      d._indexAddConnection(conn);
    } else {
      final prev = d.connByToPortId[to];
      if (prev != null) {
        d.graph = gm.deleteConnection(d.graph, prev.id);
        d._indexRemoveConnection(prev);
      }
      d.graph = gm.addConnection(d.graph, conn);
      d._indexAddConnection(conn);
    }
    _hub.fire(ConnectionAdded(from, to));
    _emitGraphChanged(d);
  }

  void deleteConnectionForInput(String toPortId) {
    if (!_hasActiveDoc) return;
    if (_isBatching) {
      _markBatchDirty();
    } else {
      _snapshot();
    }
    final d = _activeDoc!;
    final prevConn = d.connByToPortId[toPortId];
    if (prevConn == null) return;
    if (_isBatching) {
      d._indexRemoveConnection(prevConn);
      d.connsById.remove(prevConn.id);
    } else {
      d.graph = gm.deleteConnection(d.graph, prevConn.id);
      d._indexRemoveConnection(prevConn);
    }
    _hub.fire(ConnectionDeleted(prevConn.id));
    _emitGraphChanged(d);
  }

  bool hasConnectionTo(String toPortId) =>
      _activeDoc?.connByToPortId.containsKey(toPortId) ?? false;
}
