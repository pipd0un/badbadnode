// lib/domain/graph_mutations.dart

import '../models/node.dart';
import '../models/connection.dart';
import 'graph.dart';

const double kGridSize = 20.0;

//  ──────────────────────────────  nodes  ──────────────────────────────
Graph addNode(Graph g, Node n) =>
    g.copyWith(nodes: {...g.nodes, n.id: n});

Graph moveNode(Graph g, String id, double dx, double dy) {
  final n = g.nodes[id];
  if (n == null) return g;
  final nx = (n.data['x'] as num).toDouble() + dx;
  final ny = (n.data['y'] as num).toDouble() + dy;
  final moved = Node(id: n.id, type: n.type, data: {...n.data, 'x': nx, 'y': ny});
  return g.copyWith(nodes: {...g.nodes, id: moved});
}

Graph snapNode(Graph g, String id, {double gridSize = kGridSize}) {
  final n = g.nodes[id];
  if (n == null) return g;
  final rx = (n.data['x'] as num).toDouble();
  final ry = (n.data['y'] as num).toDouble();
  final sx = (rx / gridSize).round() * gridSize;
  final sy = (ry / gridSize).round() * gridSize;
  final snapped =
      Node(id: n.id, type: n.type, data: {...n.data, 'x': sx, 'y': sy});
  return g.copyWith(nodes: {...g.nodes, id: snapped});
}

Graph updateNodeData(Graph g, String id, String key, dynamic val) {
  final n = g.nodes[id];
  if (n == null) return g;
  final updated = Node(id: n.id, type: n.type, data: {...n.data, key: val});
  return g.copyWith(nodes: {...g.nodes, id: updated});
}

Graph deleteNode(Graph g, String id) {
  final conns =
      g.connections.where((c) => !c.fromPortId.startsWith('${id}_') && !c.toPortId.startsWith('${id}_')).toList();
  final nodes = {...g.nodes}..remove(id);
  return g.copyWith(nodes: nodes, connections: conns);
}

//  ────────────────────────────  connections  ─────────────────────────
Graph addConnection(Graph g, Connection c) =>
    g.copyWith(connections: [...g.connections, c]);

Graph deleteConnection(Graph g, String connectionId) =>
    g.copyWith(connections: g.connections.where((c) => c.id != connectionId).toList());

Graph deleteConnectionForInput(Graph g, String toPortId) =>
    g.copyWith(connections: g.connections.where((c) => c.toPortId != toPortId).toList());

//  ───────────────────────────────  misc  ─────────────────────────────
Graph clear(Graph g) => Graph.empty();
