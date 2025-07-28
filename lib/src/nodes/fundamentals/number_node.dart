// lib/nodes/fundamentals/number_node.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

class NumberNode extends SimpleNode {
  NumberNode() : super(extraData: {'value': 0});

  @override
  String get type => 'number';
  @override
  List<String> get inputs => const [];
  @override
  List<String> get outputs => const ['out'];

  @override
  Future run(Node node, GraphEvaluator _) async => node.data['value'];

  @override
  Widget buildWidget(Node node, WidgetRef ref) => _Body(node: node);
}

// ───────────────── UI ─────────────────
class _Body extends ConsumerWidget {
  final Node node;
  const _Body({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = node.data['value'];

    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              onTap: () async {
                final newVal = await showDialog<num?>(
                  context: context,
                  builder: (ctx) {
                    final ctl = TextEditingController(text: '$value');
                    return AlertDialog(
                      title: const Text('Edit number'),
                      content: TextField(
                        controller: ctl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, num.tryParse(ctl.text)),
                            child: const Text('OK')),
                      ],
                    );
                  },
                );
                if (newVal != null && newVal != value) {
                  NodeActions.updateData(ref, node.id, 'value', newVal);
                }
              },
              child: Text('$value', overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 4),
          OutPort(nodeId: node.id, name: 'out'),
        ],
      ),
    );
  }
}
