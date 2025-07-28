// lib/core/graph_events.dart
//
// Type-hierarchy used by MessageHub.  Widgets can listen for very
// specific events <T> or for the base class [GraphEvent].

import '../domain/graph.dart';

/// Marker interface – every graph-related event extends this.
abstract class GraphEvent {}

class NodeAdded         extends GraphEvent { final String nodeId;            NodeAdded(this.nodeId); }
class NodeMoved         extends GraphEvent { final String nodeId;      final double dx, dy; NodeMoved(this.nodeId, this.dx, this.dy); }
class NodeDeleted       extends GraphEvent { final String nodeId;            NodeDeleted(this.nodeId); }
class NodeDataChanged   extends GraphEvent { final String nodeId;            NodeDataChanged(this.nodeId); }

class ConnectionAdded   extends GraphEvent { final String fromPortId;  final String toPortId; ConnectionAdded(this.fromPortId, this.toPortId); }
class ConnectionDeleted extends GraphEvent { final String connectionId;      ConnectionDeleted(this.connectionId); }

/// Fired when the whole canvas is wiped (new file / Clear-All)
class GraphCleared      extends GraphEvent {}

/// NEW: emitted every time the immutable [Graph] value changes.
/// Lets Riverpod watch a single source of truth.
class GraphChanged      extends GraphEvent {
  final Graph graph;
  GraphChanged(this.graph);
}
