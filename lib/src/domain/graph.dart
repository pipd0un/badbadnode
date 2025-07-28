// lib/domain/graph.dart
//
// Immutable in-memory representation of a blueprint graph.

import '../models/node.dart';
import '../models/connection.dart';

class Graph {
  final Map<String, Node> nodes;         // keyed by node.id
  final List<Connection> connections;

  const Graph({
    required this.nodes,
    required this.connections,
  });

  /// Cheap structural equality helper (debug / tests only).
  @override
  bool operator ==(Object other) =>
      other is Graph &&
      other.nodes.length == nodes.length &&
      other.connections.length == connections.length &&
      other.nodes.keys.every((k) => other.nodes[k] == nodes[k]) &&
      other.connections.every(connections.contains);

  @override
  int get hashCode => Object.hashAll(nodes.values) ^ Object.hashAll(connections);

  /// Produce a shallow copy with optionally replaced fields.
  Graph copyWith({
    Map<String, Node>? nodes,
    List<Connection>? connections,
  }) =>
      Graph(
        nodes: nodes ?? this.nodes,
        connections: connections ?? this.connections,
      );

  /// Convenience factory for an empty graph.
  factory Graph.empty() => const Graph(nodes: {}, connections: []);
}
