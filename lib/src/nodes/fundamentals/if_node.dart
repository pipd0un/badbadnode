// lib/nodes/fundamentals/if_node.dart

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../../widgets/node_widget.dart' show GenericNodeWidget;
import '../simple_node.dart';

class IfNode extends SimpleNode {
  IfNode();

  @override
  String get type => 'if';
  @override
  List<String> get inputs => const ['bool', 'true', 'false'];
  @override
  List<String> get outputs => const ['result'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    var choice = node.data['activeInput'] as String?;
    // When the evaluator did not inject `activeInput`
    // (e.g. inside a Loop), compute it here.
    if (choice == null) {
      final cond = ev.input(node, 'bool') as bool? ?? false;
      choice = cond ? 'true' : 'false';
    }
  
    return ev.input(node, choice);
  }

  @override
  buildWidget(node, ref) => GenericNodeWidget(node: node);
}
