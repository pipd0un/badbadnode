// lib/nodes/fundamentals/object_node.dart
//
// Key-value sink: stores the incoming Value under Key in the evaluator.
// No outputs – it’s normally the last node of its tree.

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../../widgets/node_widget.dart' show GenericNodeWidget;
import '../simple_node.dart';

class ObjectNode extends SimpleNode {
  ObjectNode();

  @override
  String get type => 'object';
  @override
  List<String> get inputs => const ['key', 'value'];
  @override
  List<String> get outputs => const [];

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
