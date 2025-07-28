// lib/widgets/toolbar.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/graph_controller.dart';
import '../providers/graph_controller_provider.dart' show graphControllerProvider;
import '../providers/app_providers.dart' show scaffoldMessengerKeyProvider;
import '../providers/asset_provider.dart' show assetFilesProvider;
import '../providers/ui/selection_providers.dart' show selectedNodesProvider;

class Toolbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const Toolbar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<Toolbar> {
  late final GraphController _graph;

  @override
  void initState() {
    super.initState();
    _graph = ref.read(graphControllerProvider);
    _graph.on<void>().listen((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ref.read(scaffoldMessengerKeyProvider);
    final hasAssets = ref.watch(assetFilesProvider).isNotEmpty;
    final sel       = ref.watch(selectedNodesProvider);

    Future<void> showPasteJsonDialog() async {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Paste JSON'),
            content: SizedBox(
              width: 500,
              height: 300,
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste JSON here…',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (result == null || result.trim().isEmpty) return;

      try {
        final parsed = jsonDecode(result);
        if (parsed is! Map ||
            parsed['nodes'] is! List ||
            parsed['connections'] is! List) {
          throw const FormatException('Missing "nodes" or "connections"');
        }

        _graph.loadJsonMap(parsed.cast<String, dynamic>());
        messenger.currentState?.showSnackBar(const SnackBar(
            content: Text('JSON loaded from dialog'),
            duration: Duration(milliseconds: 600)));
      } catch (e) {
        messenger.currentState?.showSnackBar(SnackBar(
            content: Text('Invalid JSON: $e'),
            duration: const Duration(milliseconds: 1200)));
      }
    }


    return AppBar(
      backgroundColor: const Color.fromARGB(255, 41, 40, 40),
      title: const Text('Node Editor',
          style: TextStyle(color: Color.fromARGB(255, 255, 116, 116))),
      actions: [
        IconButton(
          icon: const Icon(Icons.undo,
              color: Color.fromARGB(255, 255, 119, 230)),
          tooltip: 'Undo',
          onPressed: _graph.canUndo ? _graph.undo : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo,
              color: Color.fromARGB(255, 255, 119, 230)),
          tooltip: 'Redo',
          onPressed: _graph.canRedo ? _graph.redo : null,
        ),

        const VerticalDivider(
            color: Color.fromARGB(255, 255, 90, 90), thickness: 2),

        // ▶ Run
        IconButton(
          tooltip: 'Run graph',
          icon: const Icon(Icons.play_arrow,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: () async {
            await _graph.evaluate();
            messenger.currentState?.showSnackBar(const SnackBar(
                content: Text('Evaluation finished'),
                duration: Duration(milliseconds: 500)));
          },
        ),

        const VerticalDivider(
            color: Color.fromARGB(255, 255, 90, 90), thickness: 2),

        // Select All / Clear
        IconButton(
          tooltip: 'Select All',
          icon: const Icon(Icons.select_all,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: () => ref
              .read(selectedNodesProvider.notifier)
              .selectAll(_graph.nodes.keys.toList()),
        ),
        IconButton(
          tooltip: 'Clear All',
          icon: const Icon(Icons.clear_all,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: () {
            _graph.clear();
            ref.read(selectedNodesProvider.notifier).clear();
          },
        ),

        const VerticalDivider(
            color: Color.fromARGB(255, 255, 90, 90), thickness: 2),

        // Clipboard
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: sel.isNotEmpty ? () => _graph.copyNodes(sel) : null,
        ),
        IconButton(
          tooltip: 'Cut',
          icon: const Icon(Icons.content_cut,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: sel.isNotEmpty
              ? () {
                  _graph.cutNodes(sel);
                  ref.read(selectedNodesProvider.notifier).clear();
                }
              : null,
        ),
        IconButton(
          tooltip: 'Paste',
          icon: const Icon(Icons.paste,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: () => _graph.pasteClipboard(100, 100),
        ),

        const VerticalDivider(
            color: Color.fromARGB(255, 255, 90, 90), thickness: 2),

        // Assets
        TextButton.icon(
          icon: Icon(
            hasAssets ? Icons.eject : Icons.folder_open,
            color: const Color.fromARGB(255, 255, 119, 230),
          ),
          label: Text(hasAssets ? 'Eject' : 'Mount',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: hasAssets
              ? () => ref.read(assetFilesProvider.notifier).clear()
              : () => ref.read(assetFilesProvider.notifier).loadAssets(),
        ),

        const VerticalDivider(
            color: Color.fromARGB(255, 255, 90, 90), thickness: 2),

        // JSON import/export
        IconButton(
          tooltip: 'Copy JSON',
          icon: const Icon(Icons.copy_all,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: () {
            Clipboard.setData(
                ClipboardData(text: jsonEncode(_graph.toJson())));
            messenger.currentState?.showSnackBar(const SnackBar(
                content: Text('Blueprint copied'),
                duration: Duration(milliseconds: 500)));
          },
        ),
        
        IconButton(
          tooltip: 'Paste JSON',
          icon: const Icon(Icons.paste,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: () {
            if (kIsWeb) {
              showPasteJsonDialog(); // Web flow with dialog
            } else {
              Clipboard.getData('text/plain').then((data) {
                try {
                  final raw = jsonDecode(data?.text ?? '{}');
                  if (raw is! Map ||
                      raw['nodes'] is! List ||
                      raw['connections'] is! List) {
                    throw FormatException('Missing "nodes" or "connections"');
                  }
                  _graph.loadJsonMap(raw.cast<String, dynamic>());
                  messenger.currentState?.showSnackBar(const SnackBar(
                      content: Text('JSON loaded'),
                      duration: Duration(milliseconds: 500)));
                } catch (e) {
                  messenger.currentState?.showSnackBar(SnackBar(
                      content: Text('Invalid JSON: $e'),
                      duration: const Duration(milliseconds: 1000)));
                }
              });
            }
          },
        ),

        IconButton(
          tooltip: 'Load JSON',
          icon: const Icon(Icons.upload_file,
              color: Color.fromARGB(255, 255, 119, 230)),
          onPressed: () async {
            await _graph.loadJsonFromFile();
            messenger.currentState?.showSnackBar(const SnackBar(
                content: Text('File loaded'),
                duration: Duration(milliseconds: 500)));
          },
        ),

        const SizedBox(width: 50),
      ],
    );
  }
}
