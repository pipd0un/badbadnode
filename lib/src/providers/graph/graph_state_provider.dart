// lib/providers/graph_state_provider.dart
//
// StateNotifier<Graph> that riverpod widgets can watch to rebuild
// exactly when the *entire* graph object changes.  It listens to the
// singleton GraphController’s `GraphChanged` events.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controller/graph_controller.dart';
import '../../core/graph_events.dart';
import '../../domain/graph.dart';

class GraphStateNotifier extends StateNotifier<Graph> {
  GraphStateNotifier._base(this.controller, Graph initial) : super(initial);

  factory GraphStateNotifier(GraphController ctrl) {
    final n = GraphStateNotifier._base(ctrl, ctrl.graph);
    n._sub = ctrl.on<GraphChanged>().listen((e) => n.state = e.graph);
    return n;
  }

  final GraphController controller;
  StreamSubscription? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final graphProvider =
    StateNotifierProvider<GraphStateNotifier, Graph>((ref) {
  return GraphStateNotifier(GraphController());
});

class GraphStateByTabNotifier extends GraphStateNotifier {
  final String _id;
  final List<StreamSubscription> _subs = [];

  GraphStateByTabNotifier(GraphController ctrl, this._id)
      : super._base(ctrl, ctrl.graphOf(_id)) {
    _subs.add(ctrl.on<TabGraphChanged>().listen((e) {
      if (e.id == _id) state = e.graph;
    }));
    _subs.add(ctrl.on<TabGraphCleared>().listen((e) {
      if (e.id == _id) state = Graph.empty();
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose(); 
  }
}

final graphProviderForTab =
    StateNotifierProvider.family<GraphStateByTabNotifier, Graph, String>(
  (ref, id) => GraphStateByTabNotifier(GraphController(), id),
);
