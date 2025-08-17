// lib/src/widgets/toolbar/menu.dart

part of '../toolbar.dart';

class _NewMenu extends StatelessWidget {
  final GraphController graph;
  const _NewMenu({required this.graph});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'New',
      icon: const Icon(
        Icons.add_box,
        color: Color.fromARGB(255, 255, 119, 230),
      ),
      itemBuilder: (ctx) => const [
        PopupMenuItem<String>(
          value: 'blueprint',
          child: Text('Blueprint'),
        ),
      ],
      onSelected: (v) {
        if (v == 'blueprint') {
          // IMPORTANT:
          // Compute the next free "Blueprint N" BEFORE creating the tab.
          // If we compute AFTER newBlueprint(), the freshly created tab's default
          // title (e.g., "Blueprint 2") is already in the list and we end up
          // renaming to "Blueprint 3" (off-by-one on first creation).
          final nextTitle = _computeNextBlueprintTitle(graph);

          // Create then normalize title to the precomputed smallest free index.
          final id = graph.newBlueprint();
          graph.renameBlueprint(id, nextTitle);

          // Arm the probe for “create + switch” path too.
          PerfSwitchProbe.start(id);
        }
      },
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(
      color: Color.fromARGB(255, 255, 90, 90),
      thickness: 1,
      width: 8,
      indent: 6,
      endIndent: 6,
    );
  }
}
