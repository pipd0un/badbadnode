// lib/nodes/_builtin_nodes.dart
//
// Collect first-party nodes and register them exactly once.

import 'fundamentals/comparator_node.dart' show ComparatorNode;
import 'fundamentals/if_node.dart' show IfNode;
import 'fundamentals/list_node.dart' show ListNode;
import 'fundamentals/loop_node.dart' show LoopNode;
import 'fundamentals/note_node.dart' show NoteNode;
import 'fundamentals/number_node.dart' show NumberNode;
import 'fundamentals/operator_node.dart' show OperatorNode;
import 'fundamentals/print_node.dart' show PrintNode;
import 'fundamentals/sink_node.dart' show SinkNode;
import 'fundamentals/string_node.dart' show StringNode;
import 'fundamentals/object_node.dart' show ObjectNode;
import 'fundamentals/getter_node.dart' show GetterNode;
import 'fundamentals/setter_node.dart' show SetterNode;
import 'node_definition.dart';

void registerBuiltInNodes() {
  NodeRegistry()
    ..register(NumberNode())
    ..register(StringNode())
    ..register(ListNode())
    ..register(OperatorNode())
    ..register(ComparatorNode())
    ..register(PrintNode())
    ..register(NoteNode())
    ..register(IfNode())
    ..register(SinkNode())
    ..register(LoopNode())
    ..register(ObjectNode())
    ..register(GetterNode())
    ..register(SetterNode());
}
