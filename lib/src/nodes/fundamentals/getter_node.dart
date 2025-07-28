// lib/nodes/fundamentals/getter_node.dart
//
// Looks up a previously-stored Object value.

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../../widgets/node_widget.dart' show GenericNodeWidget;
import '../simple_node.dart';

class GetterNode extends SimpleNode {
  GetterNode();

  @override
  String get type => 'getter';
  @override
  List<String> get inputs => const ['key'];
  @override
  List<String> get outputs => const ['value'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final k = ev.input(node, 'key');
    if (k == null) return null;
    return ev.getObject(k.toString());
  }

  @override
  buildWidget(node, ref) => GenericNodeWidget(node: node);
}
