// lib/src/core/controller/graph_controller.core.dart

library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';

import '../message_hub.dart' show MessageHub;
import '../graph_events.dart';
import '../evaluator.dart' show GraphEvaluator;

import '../../domain/graph.dart';
import '../../domain/graph_mutations.dart' as gm;

import '../../models/connection.dart';
import '../../models/node.dart';

import '../../nodes/builtin_nodes.dart' show registerBuiltInNodes;
import '../../nodes/node_definition.dart'
    show CustomNodeRegistry, NodeDefinition, NodeRegistry;
import '../../services/history_service.dart'
    show GraphHistoryService, GraphSnapshot;

part 'graph_controller.tabs.dart';
part 'graph_controller.history.dart';
part 'graph_controller.globals.dart';
part 'graph_controller.nodes.dart';
part 'graph_controller.connections.dart';
part 'graph_controller.clipboard.dart';
part 'graph_controller.eval.dart';
part 'graph_controller.io.dart';

const double kGridSize = gm.kGridSize;

/// Internal per-blueprint document bundle.
class _Doc {
  Graph graph;
  final GraphHistoryService history;
  final Map<String, dynamic> globals;
  bool globalsBootstrapped;
  String title;

  _Doc({required this.graph, required this.title})
      : history = GraphHistoryService(),
        globals = <String, dynamic>{},
        globalsBootstrapped = false {
    history.init(graph.nodes, graph.connections);
  }
}

/// Public, read-only descriptor for the tab strip.
class BlueprintTabInfo {
  final String id;
  final String title;
  const BlueprintTabInfo({required this.id, required this.title});
}

/// Base class holding shared state & helpers for mixins.
/// NOTE: Kept private to this library; mixins use `on _GraphCoreBase`.
abstract class _GraphCoreBase {
  // ───────────────── multi-doc state ─────────────────
  final MessageHub _hub = MessageHub();

  final Map<String, _Doc> _docs = {};
  String? _activeId;
  int _bpCounter = 0; // for default names

  _Doc? get _activeDoc =>
      _activeId != null ? _docs[_activeId!] : null;
  bool get _hasActiveDoc => _activeDoc != null;

  /// Seed globals used when no tab is active and copied into newly created tabs.
  final Map<String, dynamic> _seedGlobals = <String, dynamic>{};
  bool _seedGlobalsBootstrapped = false;

  // ───────────────── event stream ─────────────────
  Stream<T> on<T>() => _hub.on<T>();

  // ───────────────── id/helpers ─────────────────
  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1000)}';

  String _nodeIdFromPort(String pid) {
    final parts = pid.split('_');
    return parts.sublist(0, parts.length - 2).join('_');
  }

  // ───────────────── active graph shortcuts ─────────────────
  Graph get graph => _activeDoc?.graph ?? Graph.empty();
  Map<String, Node> get nodes => _activeDoc?.graph.nodes ?? const <String, Node>{};
  List<Connection> get connections =>
      _activeDoc?.graph.connections ?? const <Connection>[];

  // ───────────────── history helpers (used across mixins) ─────────────────
  void _snapshot() {
    final d = _activeDoc;
    if (d == null) return;
    d.history.push(d.graph.nodes, d.graph.connections);
  }

  void _restoreSnapshot(GraphSnapshot snap) {
    final d = _activeDoc;
    if (d == null) return;
    d.graph = Graph(nodes: snap.nodes, connections: snap.connections);
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId!));
    _hub.fire(GraphChanged(d.graph));
    _hub.fire(TabGraphChanged(_activeId!, d.graph));
  }

  // Cross-mixin contracts
  void deleteNode(String id);           // implemented in _NodesMixin
  void resetGlobals();                  // implemented in _GlobalsMixin
}

/// Singleton controller, composed via mixins constrained on _GraphCoreBase.
class GraphController extends _GraphCoreBase
    with
        _TabsMixin,
        _HistoryMixin,
        _GlobalsMixin,
        _NodesMixin,
        _ConnectionsMixin,
        _ClipboardMixin,
        _EvalMixin,
        _IOMixin {
  // ───────────────── singleton ─────────────────
  GraphController._internal() {
    registerBuiltInNodes();
  }
  static final GraphController _inst = GraphController._internal();
  factory GraphController() => _inst;
}
