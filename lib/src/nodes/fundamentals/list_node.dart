// lib/nodes/fundamentals/list_node.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

class ListNode extends SimpleNode {
  ListNode();

  @override
  String get type => 'list';
  @override
  List<String> get inputs => const ['in0'];
  @override
  List<String> get outputs => const ['out'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final ins = (node.data['inputs'] as List).cast<String>();
    return [for (final p in ins) ev.input(node, p)];
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
  List<String> _pins() =>
      (widget.node.data['inputs'] as List<dynamic>).cast<String>();

  void _resize(int newCount) {
    final next = List<String>.generate(newCount, (i) => 'in$i');
    for (final old in _pins()) {
      if (!next.contains(old)) {
        NodeActions.deleteConnectionForInput(
            ref, '${widget.node.id}_in_$old');
      }
    }
    NodeActions.updateData(ref, widget.node.id, 'inputs', next);
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.plus_circle),
              splashRadius: 14,
              onPressed: () => _resize(pins.length + 1),
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.minus_circle),
              splashRadius: 14,
              onPressed:
                  pins.length > 1 ? () => _resize(pins.length - 1) : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...pins.map((p) => InPort(nodeId: widget.node.id, name: p)),
        const SizedBox(height: 8),
        OutPort(nodeId: widget.node.id, name: 'out'),
      ],
    );
  }
}
