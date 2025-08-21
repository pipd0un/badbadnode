// lib/src/widgets/side_panel/panel_host.dart
//
// SidePanelHost renders the side panel chrome and hosts any number of
// injectable "panel apps" (see panel_provider.dart). It provides a VSCode-like
// Activity Bar with icons on the left, and a body area to display the active panel.
//
// Update per request:
// • Removed the bottom Hide/Show button.
// • Panel body visibility is now controlled by the panel app icons:
//    - Tapping the ACTIVE icon toggles show/hide of the body.
//    - Tapping a DIFFERENT icon switches the active app and shows the body.
// • Activity Bar (icons) always remains visible.
// • Resizer tap still toggles body; drag resizes (and expands if currently collapsed).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart'
    show
        sidePanelCollapsedProvider, // bool – "body collapsed?"
        sidePanelVisibleProvider, // bool – global panel hidden?
        sidePanelWidthProvider; // double – reserved width
import '../providers/panel_provider.dart'
    show activePanelIdProvider, panelAppsProvider;

// ────────────────────────────────────────────────────────────────────────────
// Local UI constants
// ────────────────────────────────────────────────────────────────────────────
const double _kActivityBarWidth = 44.0;
const double _kDividerWidth = 1.0;
const double _kResizerWidth = 6.0;
const double _kTopHandleHeight = 4.0;

const double _kMinExpandedWidth = 220.0;
const double _kMaxExpandedWidth = 520.0;

/// Remember the last expanded width so we can restore it when expanding.
final _savedExpandedWidthProvider = StateProvider<double>((ref) => 320.0);

// ────────────────────────────────────────────────────────────────────────────

class SidePanelHost extends ConsumerWidget {
  const SidePanelHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(sidePanelVisibleProvider); // global: whole panel
    final collapsed = ref.watch(sidePanelCollapsedProvider);
    final width = ref.watch(sidePanelWidthProvider);

    // When globally hidden, render a narrow tappable strip to reopen everything.
    if (!visible) {
      return MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            ref.read(sidePanelVisibleProvider.notifier).state = true;
          },
          onDoubleTap: () {
            ref.read(sidePanelVisibleProvider.notifier).state = true;
          },
          child: Container(
            width: 8,
            height: double.infinity,
            color: const Color.fromARGB(48, 255, 255, 255),
          ),
        ),
      );
    }

    final apps = ref.watch(panelAppsProvider);
    final activeId = ref.watch(activePanelIdProvider);
    final activeNotifier = ref.read(activePanelIdProvider.notifier);

    // Helper: update collapsed state and width together.
    void collapseBody() {
      // Save current expanded width for later restore.
      final w = ref.read(sidePanelWidthProvider);
      if (!ref.read(sidePanelCollapsedProvider)) {
        if (w >= _kMinExpandedWidth) {
          ref.read(_savedExpandedWidthProvider.notifier).state = w;
        }
      }
      // Shrink the whole panel width to just the Activity Bar (+ resizer).
      ref.read(sidePanelWidthProvider.notifier).state =
          _kActivityBarWidth + _kResizerWidth; // keep resizer grabbable
      ref.read(sidePanelCollapsedProvider.notifier).state = true;
    }

    void expandBody({double? toWidth}) {
      final saved = ref.read(_savedExpandedWidthProvider);
      final target = (toWidth ?? saved)
          .clamp(_kMinExpandedWidth, _kMaxExpandedWidth)
          .toDouble();
      ref.read(sidePanelWidthProvider.notifier).state = target;
      ref.read(sidePanelCollapsedProvider.notifier).state = false;
    }

    // Activity Bar (vertical icons).
    Widget buildActivityBar() {
      return Container(
        width: _kActivityBarWidth,
        color: const Color.fromARGB(255, 24, 24, 24),
        child: Column(
          children: [
            const SizedBox(height: 6),
            for (final a in apps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Tooltip(
                  message: a.title,
                  waitDuration: const Duration(milliseconds: 400),
                  child: InkWell(
                    onTap: () {
                      final isActive = a.id == activeId;
                      final isCollapsed = ref.read(sidePanelCollapsedProvider);

                      if (isActive) {
                        // Active icon toggles body visibility.
                        if (isCollapsed) {
                          expandBody();
                        } else {
                          collapseBody();
                        }
                      } else {
                        // Switch to another app; ensure body is visible.
                        activeNotifier.setActive(a.id);
                        if (isCollapsed) expandBody();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: a.id == activeId
                            ? const Color.fromARGB(255, 53, 52, 52)
                            : Colors.transparent,
                        border: Border.all(
                          color: a.id == activeId
                              ? const Color.fromARGB(255, 255, 119, 230)
                              : const Color.fromARGB(60, 255, 119, 230),
                        ),
                      ),
                      child: Icon(
                        a.icon,
                        size: 20,
                        color: a.id == activeId
                            ? const Color.fromARGB(255, 255, 169, 169)
                            : const Color.fromARGB(255, 220, 220, 220),
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            // (Removed) bottom Hide/Show button – handled by icons now.
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    // Layout: Activity Bar always visible; body is shown only when !collapsed.
    return Container(
      // IMPORTANT: Use the global width so Host reserves only what's needed:
      // • Expanded: user width (220–520)
      // • Collapsed: _kActivityBarWidth + resizer
      width: width,
      color: const Color.fromARGB(255, 28, 28, 28),
      child: Stack(
        children: [
          // Content beneath the full-height resizer
          Column(
            children: [
              // Drag handle (top)
              Container(
                height: _kTopHandleHeight,
                color: const Color.fromARGB(255, 22, 22, 22),
              ),
              // Activity Bar + (optional) Panel Body
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildActivityBar(),
                    if (!collapsed) ...[
                      const VerticalDivider(
                        width: _kDividerWidth,
                        thickness: _kDividerWidth,
                        color: Color.fromARGB(255, 40, 40, 40),
                      ),
                      // Panel body
                      Expanded(
                        child: SingleChildScrollView(
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: _PanelBodyHost(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Full-height resizer on the right edge:
          // • Tap toggles collapsed/expanded (body only).
          // • Drag resizes when expanded; dragging while collapsed expands.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (collapsed) {
                    expandBody();
                  } else {
                    collapseBody();
                  }
                },
                onDoubleTap: () {
                  if (collapsed) {
                    expandBody();
                  } else {
                    collapseBody();
                  }
                },
                onHorizontalDragUpdate: (d) {
                  if (ref.read(sidePanelCollapsedProvider)) {
                    // Expand on drag if currently collapsed.
                    if (d.delta.dx > 0) {
                      final target = (_kMinExpandedWidth)
                          .clamp(_kMinExpandedWidth, _kMaxExpandedWidth);
                      expandBody(toWidth: target);
                    }
                    return;
                  }
                  // Resize while expanded.
                  final newW =
                      (ref.read(sidePanelWidthProvider) + d.delta.dx)
                          .clamp(_kMinExpandedWidth, _kMaxExpandedWidth)
                          .toDouble();
                  ref.read(sidePanelWidthProvider.notifier).state = newW;
                  // Track latest valid expanded width.
                  ref.read(_savedExpandedWidthProvider.notifier).state = newW;
                },
                child: Container(
                  width: _kResizerWidth,
                  // full height by virtue of Positioned.fill vertical edges
                  color: const Color.fromARGB(64, 255, 255, 255),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small wrapper so we don’t rebuild the panel body builder unnecessarily
class _PanelBodyHost extends ConsumerWidget {
  const _PanelBodyHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(panelAppsProvider);
    final activeId = ref.watch(activePanelIdProvider);
    if (apps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'No panels registered.\n\nUse registerPanelApp(...) to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color.fromARGB(200, 255, 255, 255)),
          ),
        ),
      );
    }
    final app = apps.firstWhere(
      (a) => a.id == activeId,
      orElse: () => apps.first,
    );
    return app.builder(context, ref);
  }
}
