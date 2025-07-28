// lib/widgets/node_widget.dart
//
// Uses immutable Graph for all connection info – no ConnectionNotifier.
//
// (The fallback `PortsNodeWidget` at the bottom was rewritten to rely
//  solely on GraphController instead of the removed connectionProvider.)
// Adds special handling for 'sink' type: pill-style without header.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/node.dart';
import '../nodes/node_definition.dart' show NodeRegistry;
import '../nodes/simple_node.dart' show InPort, OutPort;
import '../providers/graph_controller_provider.dart' show graphControllerProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider, collapsedNodesProvider;
import 'port_widget.dart';

class NodeWidget extends ConsumerWidget {
  final Node node;
  const NodeWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sink node = pill without header ----------------------------------------
    if (node.type == 'sink') {
      // body already contains the pill from SinkNode.buildWidget
      final body = NodeRegistry().lookup(node.type)!.buildWidget(node, ref);
      return RepaintBoundary(child: body);
    }

    // Regular nodes ----------------------------------------------------------
    final isSel = ref.watch(
      selectedNodesProvider.select((s) => s.contains(node.id)),
    );
    final isCol = ref.watch(
      collapsedNodesProvider.select((s) => s.contains(node.id)),
    );
    final graph = ref.read(graphControllerProvider);

    final body = NodeRegistry().lookup(node.type)!.buildWidget(node, ref);

    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSel ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- header -------------------------------------------------------
          Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => ref
                      .read(collapsedNodesProvider.notifier)
                      .toggle(node.id),
                  child: Icon(isCol ? Icons.chevron_right : Icons.expand_more,
                      size: 16),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(node.type,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => graph.deleteNode(node.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          if (!isCol) ...[const SizedBox(height: 8), body],
          if (isCol) _CollapsedPorts(node: node),
        ],
      ),
    );
  }
}

class _CollapsedPorts extends StatelessWidget {
  const _CollapsedPorts({required this.node});
  final Node node;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final inp in (node.data['inputs'] as List).cast<String>())
          Align(
            alignment: Alignment.centerLeft,
            child: PortWidget(portId: '${node.id}_in_$inp', isInput: true),
          ),
        for (final out in (node.data['outputs'] as List).cast<String>())
          Align(
            alignment: Alignment.centerRight,
            child: PortWidget(portId: '${node.id}_out_$out', isInput: false),
          ),
      ],
    );
  }
}

class GenericNodeWidget extends StatelessWidget {
  final Node node;
  const GenericNodeWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final inputs  = (node.data['inputs']  as List<dynamic>? ?? const [])
        .cast<String>();
    final outputs = (node.data['outputs'] as List<dynamic>? ?? const [])
        .cast<String>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: inputs
              .map((name) => InPort(nodeId: node.id, name: name))
              .toList(),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: outputs
              .map((name) => OutPort(nodeId: node.id, name: name))
              .toList(),
        ),
      ],
    );
  }
}