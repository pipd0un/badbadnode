// lib/src/providers/hooks.dart
//
// Typical usage in the host app (outside this package):
//
// final overrides = [
//   hostInitHookProvider.overrideWithValue((graph, ref) {
//     // e.g. rename first tab to "main", register panels, set up project providers...
//     if (graph.tabs.isEmpty) {
//       final id = graph.newBlueprint();
//       graph.renameBlueprint(id, 'main');
//       graph.activateBlueprint(id);
//     }
//   }),
//   beforeCloseTabHookProvider.overrideWithValue((tabId, title, controller) async {
//     // e.g. if [title] is a saved blueprint in your project model,
//     // snapshot controller.toJson() into your project store before closing.
//   }),
// ];
//
// runApp(ProviderScope(overrides: overrides, child: NodeEditorApp()));

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller/graph_controller.core.dart' show GraphController;

/// Called once the Host initializes and a GraphController is ready.
/// Lets an app bootstrap things (rename first tab, register panels, etc).
typedef HostInitHook = void Function(GraphController controller, WidgetRef ref);

/// Optional hook: invoked by Host (post-frame) after controller is created.
final hostInitHookProvider = Provider<HostInitHook?>((ref) => null);

/// Called by the tab UI *before* a tab is closed. Apps can snapshot/persist.
typedef BeforeCloseTabHook = FutureOr<void> Function(
  String tabId,
  String title,
  GraphController controller,
);

/// Optional hook: if provided, Toolbar will call this before closing a tab.
final beforeCloseTabHookProvider =
    Provider<BeforeCloseTabHook?>((ref) => null);
