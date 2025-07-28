// lib/nodes/fundamentals/loop_node.dart

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../../widgets/node_widget.dart' show GenericNodeWidget;
import '../simple_node.dart';

class LoopNode extends SimpleNode {
  LoopNode();

  @override
  String get type => 'loop';
  @override
  List<String> get inputs => const ['in', 'process'];
  @override
  List<String> get outputs => const ['item', 'done'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final active = node.data['activeInput'] as String?;
    return active == 'item'
        ? ev.input(node, 'item')
        : ev.input(node, 'in') as List<dynamic>? ?? [];
  }

  @override
  buildWidget(node, ref) => GenericNodeWidget(node: node);
}
