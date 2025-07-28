// lib/nodes/custom/factorial_node.dart
//
// Shows how plugin authors can subclass [SimpleNode]

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import 'package:badbad/node.dart';

class FactorialNode extends SimpleNode {
  @override
  String get type => 'Factorial';
  @override
  List<String> get inputs => const ['in'];
  @override
  List<String> get outputs => const ['out'];

  @override
  Map<String, dynamic> get initialData => {
    'inputs': inputs,
    'outputs': outputs,
  };

  @override
  Future run(Node node, GraphEvaluator eval) async {
    final n = (eval.input(node, 'in') ?? 0) as num;
    int f(int k) => k < 2 ? 1 : k * f(k - 1);
    return f(n.toInt());
  }

  @override
  Widget buildWidget(Node node, WidgetRef ref) => GenericNodeWidget(node: node);
}
