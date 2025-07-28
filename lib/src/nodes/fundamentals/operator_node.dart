// lib/nodes/fundamentals/operator_node.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

const _ops = ['Add', 'Subtract', 'Multiply', 'Divide'];

class OperatorNode extends SimpleNode {
  OperatorNode() : super(extraData: {'operator': 'Add'});

  @override
  String get type => 'operator';
  @override
  List<String> get inputs => const ['a', 'b'];
  @override
  List<String> get outputs => const ['out'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final a = ev.input(node, 'a') as num? ?? 0;
    final b = ev.input(node, 'b') as num? ?? 0;
    final op = node.data['operator'] as String? ?? 'Add';
    switch (op) {
      case 'Add':
        return a + b;
      case 'Subtract':
        return a - b;
      case 'Multiply':
        return a * b;
      case 'Divide':
        return b == 0 ? null : a / b;
      default:
        return null;
    }
  }

  @override
  Widget buildWidget(Node node, WidgetRef ref) => _Body(node: node);
}

// ───────────────── UI ─────────────────
class _Body extends ConsumerStatefulWidget {
  final Node node;
  const _Body({required this.node});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late String _current;
  @override
  void initState() {
    super.initState();
    final stored = widget.node.data['operator'] as String?;
    _current = _ops.contains(stored) ? stored! : 'Add';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        InPort(nodeId: widget.node.id, name: 'a'),
        const SizedBox(height: 6),
        InPort(nodeId: widget.node.id, name: 'b'),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: _current,
          isDense: true,
          items:
              _ops.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (next) {
            if (next == null) return;
            setState(() => _current = next);
            NodeActions.updateData(ref, widget.node.id, 'operator', next);
          },
        ),
        const SizedBox(height: 8),
        OutPort(nodeId: widget.node.id, name: 'out'),
      ],
    );
  }
}
