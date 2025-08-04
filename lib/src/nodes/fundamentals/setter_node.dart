// lib/nodes/fundamentals/setter_node.dart
//
// Updates an existing Object entry (or creates one).

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../../widgets/node_widget.dart' show GenericNodeWidget;
import '../simple_node.dart';

class SetterNode extends SimpleNode {
  SetterNode();

  @override
  String get type => 'setter';
  @override 
  bool get isCommand => true;
  @override
  List<String> get inputs => const ['key', 'value'];
  @override
  List<String> get outputs => const ['then'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final k = ev.input(node, 'key');
    final v = ev.input(node, 'value');
    if (k != null) {
      ev.setObject(k.toString(), v);
    }
    return v;
  }

  @override
  buildWidget(node, ref) => GenericNodeWidget(node: node);
}
