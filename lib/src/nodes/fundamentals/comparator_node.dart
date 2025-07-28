// lib/nodes/fundamentals/comparator_node.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

const _ops = ['==', '!=', '<', '<=', '>', '>='];

class ComparatorNode extends SimpleNode {
  ComparatorNode() : super(extraData: {'operator': '=='});

  @override
  String get type => 'comparator';
  @override
  List<String> get inputs => const ['a', 'b'];
  @override
  List<String> get outputs => const ['out'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final a = ev.input(node, 'a');
    final b = ev.input(node, 'b');
    final op = node.data['operator'] as String? ?? '==';

    bool bothNums(dynamic a, dynamic b) => a is num && b is num;

    switch (op) {
      case '==': return a == b;
      case '!=': return a != b;
      case '<' : return bothNums(a, b) ? a <  b : false;
      case '<=': return bothNums(a, b) ? a <= b : false;
      case '>' : return bothNums(a, b) ? a >  b : false;
      case '>=': return bothNums(a, b) ? a >= b : false;
      default : return false;
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
    _current = _ops.contains(stored) ? stored! : '==';
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
