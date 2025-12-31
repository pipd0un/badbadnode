// lib/src/controller/graph_controller.connections.dart

part of 'graph_controller.core.dart';

// ───────────────── Connections ─────────────────

mixin _ConnectionsMixin on _GraphCoreBase {
  void addConnection(String from, String to) {
    if (!_hasActiveDoc) return;
    _snapshot();
    // Only one connection per input – remove existing
    final d = _activeDoc!;
    d.graph = gm.deleteConnectionForInput(d.graph, to);
    final conn = Connection(id: _id(), fromPortId: from, toPortId: to);
    d.graph = gm.addConnection(d.graph, conn);
    _hub.fire(ConnectionAdded(from, to));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  void deleteConnectionForInput(String toPortId) {
    if (!_hasActiveDoc) return;
    _snapshot();
    final d = _activeDoc!;
    final prevConn = d.graph.connections.firstWhere(
      (c) => c.toPortId == toPortId,
      orElse: () => Connection(id: '', fromPortId: '', toPortId: ''),
    );
    d.graph = gm.deleteConnectionForInput(d.graph, toPortId);
    if (prevConn.id.isNotEmpty) {
      _hub.fire(ConnectionDeleted(prevConn.id));
    }
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  bool hasConnectionTo(String toPortId) =>
      _activeDoc?.graph.connections.any((c) => c.toPortId == toPortId) ?? false;
}
