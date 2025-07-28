// lib/providers/graph_state_provider.dart
//
// StateNotifier<Graph> that riverpod widgets can watch to rebuild
// exactly when the *entire* graph object changes.  It listens to the
// singleton GraphController’s `GraphChanged` events.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/graph_controller.dart';
import '../core/graph_events.dart';
import '../domain/graph.dart';

class GraphStateNotifier extends StateNotifier<Graph> {
  GraphStateNotifier(this._ctrl)
      : super(_ctrl.graph) {
    _sub = _ctrl.on<GraphChanged>().listen((e) => state = e.graph);
  }

  final GraphController _ctrl;
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Single immutable source-of-truth provider.
/// Widgets can now do: 'final graph = ref.watch(graphProvider);'
final graphProvider =
    StateNotifierProvider<GraphStateNotifier, Graph>((ref) {
  return GraphStateNotifier(GraphController());
});
