// lib/nodes/fundamentals/print_node.dart

import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import '../../core/evaluator.dart' show GraphEvaluator;
import '../../models/node.dart' show Node;
import '../../services/snackbar_service.dart' show SnackbarService;
import '../../widgets/node_widget.dart' show GenericNodeWidget;
import '../simple_node.dart' show SimpleNode;

class PrintNode extends SimpleNode {
  PrintNode();

  @override
  String get type => 'print';
  @override
  bool get isCommand => true;
  @override
  List<String> get inputs => const ['in'];
  @override
  List<String> get outputs => const [];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final v = ev.input(node, 'in');
    dev.log('🖨️  $v');
    SnackbarService.show('$v');
  }

  @override
  Widget buildWidget(Node node, WidgetRef ref) => GenericNodeWidget(node: node);
}