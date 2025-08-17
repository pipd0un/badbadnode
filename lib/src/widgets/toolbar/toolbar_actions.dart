// lib/src/widgets/toolbar/toolbar_actions.dart

part of '../toolbar.dart';

/// Extracted actions row for readability/maintainability.
/// Keeps identical behavior to the original monolithic Toolbar.
class ToolbarActions extends ConsumerWidget {
  final GraphController graph;
  final bool isWeb;
  const ToolbarActions({super.key, required this.graph, required this.isWeb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messenger = ref.read(scaffoldMessengerKeyProvider);
    final hasAssets = ref.watch(assetFilesProvider).isNotEmpty;
    const double iconSz = 18.0;

    Future<void> handlePasteJson() async {
      if (isWeb) {
        final result = await showPasteJsonDialog(context);
        if (result == null) return;

        try {
          final parsed = jsonDecode(result);
          if (parsed is! Map ||
              parsed['nodes'] is! List ||
              parsed['connections'] is! List) {
            throw const FormatException('Missing "nodes" or "connections"');
          }
          graph.loadJsonMap(parsed.cast<String, dynamic>());
          messenger.currentState?.showSnackBar(
            const SnackBar(
              content: Text('JSON loaded from dialog'),
              duration: Duration(milliseconds: 600),
            ),
          );
        } catch (e) {
          messenger.currentState?.showSnackBar(
            SnackBar(
              content: Text('Invalid JSON: $e'),
              duration: const Duration(milliseconds: 1200),
            ),
          );
        }
      } else {
        final data = await Clipboard.getData('text/plain');
        try {
          final raw = jsonDecode(data?.text ?? '{}');
          if (raw is! Map ||
              raw['nodes'] is! List ||
              raw['connections'] is! List) {
            throw const FormatException('Missing "nodes" or "connections"');
          }
          graph.loadJsonMap(raw.cast<String, dynamic>());
          messenger.currentState?.showSnackBar(
            const SnackBar(
              content: Text('JSON loaded'),
              duration: Duration(milliseconds: 500),
            ),
          );
        } catch (e) {
          messenger.currentState?.showSnackBar(
            SnackBar(
              content: Text('Invalid JSON: $e'),
              duration: const Duration(milliseconds: 1000),
            ),
          );
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: iconSz,
          icon: const Icon(
            Icons.undo,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          tooltip: 'Undo',
          onPressed: graph.canUndo ? graph.undo : null,
        ),
        IconButton(
          iconSize: iconSz,
          icon: const Icon(
            Icons.redo,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          tooltip: 'Redo',
          onPressed: graph.canRedo ? graph.redo : null,
        ),

        const _ThinDivider(),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Run graph (active tab)',
          icon: const Icon(
            Icons.play_arrow,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () async {
            await graph.evaluate();
            ref.read(scaffoldMessengerKeyProvider).currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('Evaluation finished'),
                    duration: Duration(milliseconds: 500),
                  ),
                );
          },
        ),

        const _ThinDivider(),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Select All',
          icon: const Icon(
            Icons.select_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () => ref
              .read(selectedNodesProvider.notifier)
              .selectAll(graph.nodes.keys.toList()),
        ),
        IconButton(
          iconSize: iconSz,
          tooltip: 'Clear All',
          icon: const Icon(
            Icons.clear_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            graph.clear();
            ref.read(selectedNodesProvider.notifier).clear();
          },
        ),

        const _ThinDivider(),

        TextButton.icon(
          icon: Icon(
            hasAssets ? Icons.eject : Icons.folder_open,
            color: const Color.fromARGB(255, 255, 119, 230),
            size: iconSz,
          ),
          label: const Text(
            // thinner label
            '',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          onPressed: hasAssets
              ? () => ref.read(assetFilesProvider.notifier).clear()
              : () => ref.read(assetFilesProvider.notifier).loadAssets(),
          style: TextButton.styleFrom(
            minimumSize: const Size(28, 28),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ),

        const _ThinDivider(),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Copy JSON',
          icon: const Icon(
            Icons.copy_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonEncode(graph.toJson())));
            ref.read(scaffoldMessengerKeyProvider).currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('Blueprint copied'),
                    duration: Duration(milliseconds: 500),
                  ),
                );
          },
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Paste JSON',
          icon: const Icon(
            Icons.paste,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: handlePasteJson,
        ),

        IconButton(
          iconSize: iconSz,
          tooltip: 'Load JSON',
          icon: const Icon(
            Icons.upload_file,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () async {
            await graph.loadJsonFromFile();
            ref.read(scaffoldMessengerKeyProvider).currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('File loaded'),
                    duration: Duration(milliseconds: 500),
                  ),
                );
          },
        ),
      ],
    );
  }
}
