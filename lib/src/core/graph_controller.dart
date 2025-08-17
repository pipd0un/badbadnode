// lib/src/controller/graph_controller.dart

library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'dart:developer' as dev;
import 'package:file_picker/file_picker.dart';

import 'message_hub.dart' show MessageHub;
import 'graph_events.dart';
import 'evaluator.dart' show GraphEvaluator;

import '../domain/graph.dart';
import '../domain/graph_mutations.dart' as gm;

import '../models/connection.dart';
import '../models/node.dart';

import '../nodes/builtin_nodes.dart' show registerBuiltInNodes;
import '../nodes/node_definition.dart'
    show CustomNodeRegistry, NodeDefinition, NodeRegistry;
import '../services/history_service.dart'
    show GraphHistoryService, GraphSnapshot;

part 'controller/graph_controller.core.dart';
part 'controller/graph_controller.tabs.dart';
part 'controller/graph_controller.history.dart';
part 'controller/graph_controller.globals.dart';
part 'controller/graph_controller.nodes.dart';
part 'controller/graph_controller.connections.dart';
part 'controller/graph_controller.clipboard.dart';
part 'controller/graph_controller.eval.dart';
part 'controller/graph_controller.io.dart';

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
  String _activeId = '';
  int _bpCounter = 1; // for default names

  _Doc get _doc => _docs[_activeId]!;

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
  Graph get graph => _doc.graph;
  Map<String, Node> get nodes => _doc.graph.nodes;
  List<Connection> get connections => _doc.graph.connections;

  // ───────────────── history helpers (used across mixins) ─────────────────
  void _snapshot() => _doc.history.push(_doc.graph.nodes, _doc.graph.connections);

  void _restoreSnapshot(GraphSnapshot snap) {
    _doc.graph = Graph(nodes: snap.nodes, connections: snap.connections);
    _hub.fire(GraphCleared());
    _hub.fire(TabGraphCleared(_activeId));
    _hub.fire(GraphChanged(_doc.graph));
    _hub.fire(TabGraphChanged(_activeId, _doc.graph));
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
    // create first blank blueprint
    _openNewBlueprintInternal(
      title: 'Blueprint 1',
      makeActive: true,
      fireEvents: false,
    );
    // announce initial states to any stacked canvases
    _hub.fire(BlueprintOpened(_activeId, _docs[_activeId]!.title));
    _hub.fire(ActiveBlueprintChanged(_activeId));
    _hub.fire(TabGraphChanged(_activeId, _docs[_activeId]!.graph));
    _hub.fire(GraphChanged(_docs[_activeId]!.graph)); // legacy listeners
  }
  static final GraphController _inst = GraphController._internal();
  factory GraphController() => _inst;
}
