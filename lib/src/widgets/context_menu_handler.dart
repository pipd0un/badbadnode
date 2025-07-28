// lib/widgets/context_menu_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerWidget, WidgetRef;

import '../models/node.dart' show Node;
import '../nodes/node_definition.dart' show CustomNodeRegistry;
import '../providers/graph_controller_provider.dart' show graphControllerProvider;
import '../providers/ui/selection_providers.dart' show collapsedNodesProvider, selectedNodesProvider;

class ContextMenuHandler extends ConsumerWidget {
  final GlobalKey canvasKey;
  final Widget child;
  const ContextMenuHandler({
    super.key,
    required this.canvasKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.read(graphControllerProvider);
    final sel = ref.watch(selectedNodesProvider);
    final selNot = ref.read(selectedNodesProvider.notifier);
    final collNot = ref.read(collapsedNodesProvider.notifier);
    
    MenuItem leaf(String t, Offset gPos, RenderBox box) => MenuItem(
      label: '${t[0].toUpperCase()}${t.substring(1)}',
      onSelected: () {
        final local = box.globalToLocal(gPos);
        graph.addNodeOfType(t, local.dx, local.dy);
      },
    );

    Future<void> backgroundMenu(Offset gPos) async {
      final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;

      const primitives = ['number', 'string', 'list'];
      const ops = ['operator', 'comparator', 'if', 'loop'];
      const dev = ['print', 'sink'];
      const global = ['object', 'getter', 'setter'];

      final libs = <ContextMenuEntry>[
        MenuItem.submenu(
          label: 'Primitives',
          items: primitives.map((t) => leaf(t, gPos, box)).toList(),
        ),
        MenuItem.submenu(
          label: 'Basic Ops',
          items: ops.map((t) => leaf(t, gPos, box)).toList(),
        ),
        MenuItem.submenu(
          label: 'Dev',
          items: dev.map((t) => leaf(t, gPos, box)).toList(),
        ),
        MenuItem.submenu(
          label: 'Global',
          items: global.map((t) => leaf(t, gPos, box)).toList(),
        ),
      ];

      final grouped = CustomNodeRegistry().groupedByCategory;
      for (final entry in grouped.entries) {
        final nodes = entry.value..sort((a, b) => a.type.compareTo(b.type));
        if (grouped.entries.isNotEmpty) libs.add(MenuDivider());
        libs.add(
          MenuItem.submenu(
            label: entry.key,
            items: nodes.map((n) => leaf(n.type, gPos, box)).toList(),
          ),
        );
      }

      await showContextMenu(
        context,
        contextMenu: ContextMenu(
          position: gPos,
          entries: <ContextMenuEntry>[
            const _Title(text: 'Foundation ©'),
            MenuDivider(),
            MenuItem(
              icon: Icons.paste_rounded,
              label: 'Paste',
              onSelected: () {
                final local = box.globalToLocal(gPos);
                graph.pasteClipboard(local.dx, local.dy);
              },
            ),
            MenuDivider(),
            MenuItem.submenu(
              icon: Icons.storage_rounded,
              label: 'Library',
              items: libs,
            ),
          ],
        ),
      );
    }

    Future<void> nodeMenu(Offset gPos, Node node) async {
      if (!sel.contains(node.id)) {
        selNot
          ..clear()
          ..select(node.id);
      }

      await showContextMenu(
        context,
        contextMenu: ContextMenu(
          position: gPos,
          entries: <ContextMenuEntry>[
            MenuItem(
              label: 'Cut',
              onSelected: () {
                graph.cutNodes(sel);
                selNot.clear();
              },
            ),
            MenuItem(label: 'Copy', onSelected: () => graph.copyNodes(sel)),
            MenuItem(
              label: 'Delete',
              onSelected: () {
                for (final id in sel) {
                  graph.deleteNode(id);
                }
                selNot.clear();
              },
            ),
            const MenuDivider(),
            MenuItem(
              label: 'Collapse',
              onSelected: () => sel.forEach(collNot.toggle),
            ),
          ],
        ),
      );
    }

    Node? hitNode(Offset gPos) {
      final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return null;
      final local = box.globalToLocal(gPos);
      for (final n in graph.nodes.values.toList().reversed) {
        final x = (n.data['x'] as num).toDouble();
        final y = (n.data['y'] as num).toDouble();
        if (Rect.fromLTWH(x, y, 160, 80).contains(local)) return n;
      }
      return null;
    }

    return Listener(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (d) {
          final pos = d.globalPosition;
          final hit = hitNode(pos);
          hit != null ? nodeMenu(pos, hit) : backgroundMenu(pos);
        },
        child: child,
      ),
    );
  }
}

final class _Title extends ContextMenuEntry<Never> {
  final String text;
  const _Title({required this.text});
  @override
  Widget builder(BuildContext ctx, ContextMenuState _) => Padding(
    padding: const EdgeInsets.all(8),
    child: Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
