// lib/services/history_service.dart
//
// Pure-Dart undo/redo stack — moved here from controller folder.
// NO Flutter / Riverpod / UI imports.

import '../models/node.dart';
import '../models/connection.dart';

/// Snapshot of a complete graph state.
class GraphSnapshot {
  final Map<String, Node> nodes;
  final List<Connection> connections;
  const GraphSnapshot(this.nodes, this.connections);
}

/// Generic history manager (push / undo / redo).
class GraphHistoryService {
  final List<GraphSnapshot> _history = [];
  int _currentIndex = -1;

  // Initialise with an initial graph.
  void init(Map<String, Node> nodes, List<Connection> conns) {
    _history
      ..clear()
      ..add(GraphSnapshot(_copyNodes(nodes), _copyConns(conns)));
    _currentIndex = 0;
  }

  void push(
    Map<String, Node> nodes,
    List<Connection> conns, {
    bool initial = false,
  }) {
    if (!initial && _currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    _history.add(GraphSnapshot(_copyNodes(nodes), _copyConns(conns)));
    _currentIndex++;
  }

  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;

  GraphSnapshot undo() {
    if (!canUndo) throw StateError('No undo information');
    _currentIndex--;
    return _history[_currentIndex];
  }

  GraphSnapshot redo() {
    if (!canRedo) throw StateError('No redo information');
    _currentIndex++;
    return _history[_currentIndex];
  }

  // ───────── helper deep-copies ─────────
  // NOTE: Nodes/Connections are treated as immutable. This enables structural
  // sharing between snapshots (fast + low-GC) while keeping graph mutations
  // purely functional (they create new Node/Connection objects as needed).
  Map<String, Node> _copyNodes(Map<String, Node> src) =>
      Map<String, Node>.unmodifiable(src);

  List<Connection> _copyConns(List<Connection> src) =>
      List<Connection>.unmodifiable(src);
}
