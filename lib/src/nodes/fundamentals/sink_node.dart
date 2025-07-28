// lib/nodes/fundamentals/sink_node.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

class SinkNode extends SimpleNode {
  SinkNode();

  @override
  String get type => 'sink';
  @override
  List<String> get inputs => const ['in'];
  @override
  List<String> get outputs => const ['out'];

  @override
  Future run(Node node, GraphEvaluator ev) async => ev.input(node, 'in');

  @override
  Widget buildWidget(Node node, WidgetRef ref) => _Pill(node: node);
}

// ───────────────── UI ─────────────────
class _Pill extends StatelessWidget {
  final Node node;
  const _Pill({required this.node});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InPort(nodeId: node.id, name: 'in'),
            const SizedBox(width: 32),
            OutPort(nodeId: node.id, name: 'out'),
          ],
        ),
      );
}
