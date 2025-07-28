// lib/providers/ui/selection_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedNodesNotifier extends StateNotifier<Set<String>> {
  SelectedNodesNotifier() : super({});

  void clear() => state = {};
  void select(String id) => state = {...state, id};
  void deselect(String id) => state = {...state}..remove(id);
  void selectAll(List<String> ids) => state = ids.toSet();
  void replaceWith(String id) => state = {id};
}

final selectedNodesProvider =
    StateNotifierProvider<SelectedNodesNotifier, Set<String>>(
  (_) => SelectedNodesNotifier(),
);

class CollapsedNodesNotifier extends StateNotifier<Set<String>> {
  CollapsedNodesNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  bool isCollapsed(String id) => state.contains(id);
}

final collapsedNodesProvider =
    StateNotifierProvider<CollapsedNodesNotifier, Set<String>>(
  (_) => CollapsedNodesNotifier(),
);
