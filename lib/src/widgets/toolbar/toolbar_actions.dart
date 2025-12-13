// lib/src/widgets/toolbar/toolbar_actions.dart
//
// ToolbarActions buttons, routed to the *active canvas ProviderContainer*
// so actions like "Select All" affect the correct tab-scoped providers.

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
    const double iconSz = 18.0;

    // Helper to read from active canvas container (falls back to root)
    T inActiveContainer<T>({
      required T Function(ProviderContainer c) fn,
      required T Function() fallback,
    }) {
      return ActiveCanvasContainerLink.instance.withActive(
        fn: fn,
        fallback: fallback,
      );
    }

    Set<String> currentSelection() {
      return inActiveContainer<Set<String>>(
        fn: (c) => c.read(selectedNodesProvider),
        fallback: () => ref.read(selectedNodesProvider),
      );
    }

    void setSelection(Set<String> ids) {
      inActiveContainer<void>(
        fn: (c) {
          final n = c.read(selectedNodesProvider.notifier);
          // Works for both Notifier<T> and StateNotifier<T>
          // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          n.state = ids;
        },
        fallback: () {
          final n = ref.read(selectedNodesProvider.notifier);
          // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          n.state = ids;
        },
      );
    }

    Future<void> pasteJsonFromClipboard() async {
      try {
        if (isWeb) {
          final pasted = await showPasteJsonDialog(context);
          if (pasted == null || pasted.trim().isEmpty) return;
          final raw = jsonDecode(pasted);
          if (raw is! Map ||
              raw['nodes'] is! List ||
              raw['connections'] is! List) {
            throw const FormatException('Missing "nodes" or "connections"');
          }
          graph.loadJsonMap(raw.cast<String, dynamic>());
        } else {
          final data = await Clipboard.getData('text/plain');
          final raw = jsonDecode(data?.text ?? '{}');
          if (raw is! Map ||
              raw['nodes'] is! List ||
              raw['connections'] is! List) {
            throw const FormatException('Missing "nodes" or "connections"');
          }
          graph.loadJsonMap(raw.cast<String, dynamic>());
        }
        messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text('JSON loaded'),
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
            try {
              await graph.evaluate();
              messenger.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('Evaluation finished'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            } catch (e) {
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Evaluation error'),
                  content: SingleChildScrollView(
                    child: Text('$e'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          },
        ),

        const _ThinDivider(),

        // SELECT ALL
        IconButton(
          iconSize: iconSz,
          tooltip: 'Select All',
          icon: const Icon(
            Icons.select_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            setSelection(graph.nodes.keys.toSet());
          },
        ),

        // CLEAR ALL
        IconButton(
          iconSize: iconSz,
          tooltip: 'Clear All',
          icon: const Icon(
            Icons.clear_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            graph.clear();
            setSelection(<String>{});
          },
        ),

        const _ThinDivider(),

        // COPY
        IconButton(
          iconSize: iconSz,
          tooltip: 'Copy',
          icon: const Icon(
            Icons.copy,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            final sel = currentSelection();
            if (sel.isEmpty) return;
            graph.copyNodes(sel);
          },
        ),

        // CUT
        IconButton(
          iconSize: iconSz,
          tooltip: 'Cut',
          icon: const Icon(
            Icons.content_cut,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            final sel = currentSelection();
            if (sel.isEmpty) return;
            graph.cutNodes(sel);
            setSelection(<String>{});
          },
        ),

        // PASTE
        IconButton(
          iconSize: iconSz,
          tooltip: 'Paste (into active tab)',
          icon: const Icon(
            Icons.paste,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () => graph.pasteClipboard(100, 100),
        ),

        const _ThinDivider(),

        // COPY JSON
        IconButton(
          iconSize: iconSz,
          tooltip: 'Copy JSON',
          icon: const Icon(
            Icons.copy_all,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonEncode(graph.toJson())));
            messenger.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Blueprint copied'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        ),

        // PASTE JSON
        IconButton(
          iconSize: iconSz,
          tooltip: 'Paste JSON',
          icon: const Icon(
            Icons.paste,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: pasteJsonFromClipboard,
        ),

        // LOAD JSON (file)
        IconButton(
          iconSize: iconSz,
          tooltip: 'Load JSON',
          icon: const Icon(
            Icons.upload_file,
            color: Color.fromARGB(255, 255, 119, 230),
          ),
          onPressed: () async {
            await graph.loadJsonFromFile();
            messenger.currentState?.showSnackBar(
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
