// lib/nodes/fundamentals/string_node.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

class StringNode extends SimpleNode {
  StringNode() : super(extraData: {'value': ''});

  @override
  String get type => 'string';
  @override
  List<String> get inputs => const [];
  @override
  List<String> get outputs => const ['out'];

  @override
  Future run(Node node, GraphEvaluator _) async =>
      node.data['value']?.toString() ?? '';

  @override
  Widget buildWidget(Node node, WidgetRef ref) => _Body(node: node);
}

// ───────────────── UI ─────────────────
class _Body extends ConsumerWidget {
  final Node node;
  const _Body({required this.node});

  String _preview(String txt) {
    if (txt.isEmpty) return '<empty>';
    final flat = txt.replaceAll('\n', ' ');
    return flat.length <= 18 ? flat : '${flat.substring(0, 17)}…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = node.data['value'] ?? '';

    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              onTap: () async {
                final nxt = await showDialog<String?>(
                  context: context,
                  builder: (ctx) {
                    final ctl = TextEditingController(text: value);
                    return AlertDialog(
                      title: const Text('Edit text'),
                      content: TextField(
                        controller: ctl,
                        maxLines: null,
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, ctl.text),
                            child: const Text('OK')),
                      ],
                    );
                  },
                );
                if (nxt != null && nxt != value) {
                  NodeActions.updateData(ref, node.id, 'value', nxt);
                }
              },
              child: Text(_preview(value), overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 4),
          OutPort(nodeId: node.id, name: 'out'),
        ],
      ),
    );
  }
}
