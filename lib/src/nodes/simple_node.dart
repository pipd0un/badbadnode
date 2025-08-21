// lib/simple_node.dart
//
// Unified minimal-authoring API for 'bad bad node'.
//   • SimpleNode   – base class
//   • NodeActions  – high-level helpers
//   • InPort / OutPort – drag-enabled port widgets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller/graph_controller.core.dart';
import '../providers/connection/connection_providers.dart';
import '../providers/graph/graph_controller_provider.dart';
import '../providers/ui/canvas_providers.dart';
import '../widgets/port_widget.dart';
import 'node_definition.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// SimpleNode – minimal base every concrete node extends
/// ─────────────────────────────────────────────────────────────────────────
abstract class SimpleNode extends NodeDefinition {
  SimpleNode({Map<String, dynamic>? extraData}) : _extra = extraData;

  final Map<String, dynamic>? _extra;

  @override
  Map<String, dynamic> get initialData => {
        'inputs': inputs,
        'outputs': outputs,
        if (_extra != null) ..._extra,
      };
}

/// ─────────────────────────────────────────────────────────────────────────
/// Helpers – hide provider / controller plumbing
/// ─────────────────────────────────────────────────────────────────────────
class NodeActions {
  static GraphController _ctl(WidgetRef ref) =>
      ref.read(graphControllerProvider);

  // metadata
  static void updateData(
          WidgetRef ref, String nodeId, String key, dynamic value) =>
      _ctl(ref).updateNodeData(nodeId, key, value);

  // connections
  static bool hasConnectionTo(WidgetRef ref, String portId) =>
      _ctl(ref).hasConnectionTo(portId);

  static void deleteConnectionForInput(WidgetRef ref, String portId) =>
      _ctl(ref).deleteConnectionForInput(portId);

  static void addConnection(
          WidgetRef ref, String fromPort, String toPort) =>
      _ctl(ref).addConnection(fromPort, toPort);

  // drag preview
  static String? startPort(WidgetRef ref) =>
      ref.watch(connectionStartPortProvider);

  static void setStartPort(WidgetRef ref, String? portId) =>
      ref.read(connectionStartPortProvider.notifier).state = portId;

  static void setDragPos(WidgetRef ref, Offset global) {
    final box = ref
        .read(connectionCanvasKeyProvider)
        .currentContext
        ?.findRenderObject() as RenderBox?;
    if (box != null) {
      ref.read(connectionDragPosProvider.notifier).state =
          box.globalToLocal(global);
    }
  }

  // expose controller when absolutely needed
  static GraphController controller(WidgetRef ref) => _ctl(ref);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Port widgets
/// ─────────────────────────────────────────────────────────────────────────
class InPort extends ConsumerWidget {
  final String nodeId;
  final String name;
  const InPort({required this.nodeId, required this.name, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pid   = '${nodeId}_in_$name';
    final ctl   = NodeActions.controller(ref);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        final global   = d.globalPosition;
        final dragging = NodeActions.startPort(ref);
        final occupied = NodeActions.hasConnectionTo(ref, pid);

        // ── CASE 1: user drags a cable onto this pin ────────────────
        if (dragging != null && dragging != pid) {
          if (occupied) {
            // detach old wire → give it to cursor, DO NOT auto-connect new one
            final old = ctl.connections.firstWhere((c) => c.toPortId == pid);
            NodeActions.deleteConnectionForInput(ref, pid);
            NodeActions.setStartPort(ref, old.fromPortId);
            NodeActions.setDragPos(ref, global);
          } else {
            // simple connect
            NodeActions.addConnection(ref, dragging, pid);
            NodeActions.setStartPort(ref, null);
          }
          return;
        }

        // ── CASE 2: click / drag to detach existing wire ────────────
        if (dragging == null && occupied) {
          final old = ctl.connections.firstWhere((c) => c.toPortId == pid);
          NodeActions.deleteConnectionForInput(ref, pid);
          NodeActions.setStartPort(ref, old.fromPortId);
          NodeActions.setDragPos(ref, global);
        }
      },
      child: Row(
        children: [
          PortWidget(portId: pid, isInput: true),
          const SizedBox(width: 4),
          Text(name),
        ],
      ),
    );
  }
}

class OutPort extends ConsumerWidget {
  final String nodeId;
  final String name;
  const OutPort({required this.nodeId, required this.name, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portId = '${nodeId}_out_$name';

    void startDrag(Offset global) {
      NodeActions.setStartPort(ref, portId);
      NodeActions.setDragPos(ref, global);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => startDrag(d.globalPosition),
      onPanStart: (d) => startDrag(d.globalPosition),
      onPanUpdate: (d) => NodeActions.setDragPos(ref, d.globalPosition),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(name),
          const SizedBox(width: 4),
          PortWidget(portId: portId, isInput: false),
        ],
      ),
    );
  }
}
