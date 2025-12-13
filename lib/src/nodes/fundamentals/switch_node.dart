// lib/nodes/fundamentals/switch_node.dart
//
// Switch-case node:
//   • 1 input:  "switch"
//   • N pairs:  "keyX", "valueX"
//   • 1 output: "out"
//
// It checks all key inputs; if any equals the switch
// value, it returns the corresponding value input.
// If none match, it throws – the toolbar wraps this
// into a user-visible error dialog.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/node.dart';
import '../../core/evaluator.dart';
import '../simple_node.dart';

class SwitchNode extends SimpleNode {
  SwitchNode();

  @override
  String get type => 'switch';

  @override
  List<String> get inputs =>
      const ['switch', 'key0', 'value0', 'key1', 'value1'];

  @override
  List<String> get outputs => const ['out'];

  @override
  Future run(Node node, GraphEvaluator ev) async {
    final switchVal = ev.input(node, 'switch');
    final pins = (node.data['inputs'] as List<dynamic>? ?? const [])
        .cast<String>();

    // All pins except the primary "switch" are key/value pairs.
    final pairPins = pins.where((p) => p != 'switch').toList();

    for (var i = 0; i + 1 < pairPins.length; i += 2) {
      final keyName = pairPins[i];
      final valName = pairPins[i + 1];
      final keyVal = ev.input(node, keyName);
      if (keyVal == switchVal) {
        return ev.input(node, valName);
      }
    }

    final swStr = switchVal?.toString() ?? 'null';
    throw Exception('Switch node: no matching key for "$swStr"');
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
      (widget.node.data['inputs'] as List<dynamic>? ?? const [])
          .cast<String>();

  void _addPair() {
    final pins = _pins();
    // Excluding the "switch" pin, every 2 pins are one key/value pair.
    final existingPairs = pins.where((p) => p != 'switch').length ~/ 2;
    final nextKey = 'key$existingPairs';
    final nextVal = 'value$existingPairs';

    final nextPins = [...pins, nextKey, nextVal];
    NodeActions.updateData(ref, widget.node.id, 'inputs', nextPins);
  }

  void _removePair() {
    final pins = _pins();
    // Keep at least one key/value pair.
    final pairCount = pins.where((p) => p != 'switch').length ~/ 2;
    if (pairCount <= 1) return;

    // Drop the last two non-switch pins.
    final pairPins = pins.where((p) => p != 'switch').toList();
    final toRemove = pairPins.sublist(pairPins.length - 2);
    final nextPins = [
      for (final p in pins)
        if (!toRemove.contains(p)) p,
    ];
    NodeActions.updateData(ref, widget.node.id, 'inputs', nextPins);
  }

  @override
  Widget build(BuildContext context) {
    final pins = _pins();
    final switchPin =
        pins.contains('switch') ? 'switch' : (pins.isNotEmpty ? pins.first : 'switch');
    final pairPins = pins.where((p) => p != switchPin).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.plus_circle),
              splashRadius: 14,
              onPressed: _addPair,
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.minus_circle),
              splashRadius: 14,
              onPressed: pairPins.length > 2 ? _removePair : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        InPort(nodeId: widget.node.id, name: switchPin),
        for (var i = 0; i < pairPins.length; i++) ...[
          if (i == 0 || i.isEven) const SizedBox(height: 8),
          InPort(nodeId: widget.node.id, name: pairPins[i]),
        ],
        const SizedBox(height: 8),
        OutPort(nodeId: widget.node.id, name: 'out'),
      ],
    );
  }
}
