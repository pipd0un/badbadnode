// lib/src/controller/graph_controller.eval.dart

part of 'graph_controller.core.dart';

// ───────────────── Evaluation (active tab only) ─────────────────

mixin _EvalMixin on _GraphCoreBase {
  Future<Map<String, dynamic>> evaluate() async {
    return GraphEvaluator(this as GraphController).run();
  }

  Future<Map<String, dynamic>> evaluateFrom(String nodeId) async {
    return GraphEvaluator(this as GraphController).evaluateFrom(nodeId);
  }
}
