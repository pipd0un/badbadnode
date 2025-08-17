// lib/src/widgets/toolbar/tabs_strip.dart

part of '../toolbar.dart';

class _TabsStrip extends StatelessWidget {
  final GraphController controller;
  final double height;
  const _TabsStrip({required this.controller, required this.height});

  @override
  Widget build(BuildContext context) {
    final tabs = controller.tabs;
    final active = controller.activeBlueprintId;

    return Container(
      color: const Color.fromARGB(255, 36, 35, 35),
      height: height,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'New Blueprint',
            icon: const Icon(
              Icons.add,
              size: 16,
              color: Color.fromARGB(255, 255, 119, 230),
            ),
            onPressed: () {
              // IMPORTANT:
              // Compute the next free "Blueprint N" BEFORE creating the tab.
              // Otherwise the freshly added default title is counted and we jump to N+1.
              final nextTitle = _computeNextBlueprintTitle(controller);

              // Create and immediately normalize its title to the smallest free index.
              final id = controller.newBlueprint();
              controller.renameBlueprint(id, nextTitle);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  for (final t in tabs)
                    _TabChip(
                      key: ValueKey(t.id), // ensure state (e.g., _pressed) is scoped per tab
                      id: t.id,
                      title: t.title,
                      isActive: t.id == active,
                      controller: controller,
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
