// lib/src/controller/graph_controller.tabs.dart

part of '../graph_controller.dart';

// ───────────────── tab API (public) ─────────────────

mixin _TabsMixin on _GraphCoreBase {
  List<BlueprintTabInfo> get tabs => [
        for (final e in _docs.entries)
          BlueprintTabInfo(id: e.key, title: e.value.title),
      ];
  String get activeBlueprintId => _activeId;

  /// Lookup the Graph for a specific blueprint id.
  Graph graphOf(String id) => _docs[id]?.graph ?? Graph.empty();

  /// Open a new empty blueprint and activate it.
  String newBlueprint({String? title}) {
    final t = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'Blueprint ${++_bpCounter}';
    final id = _openNewBlueprintInternal(
      title: t,
      makeActive: true,
      fireEvents: true,
    );
    return id;
  }

  /// Close a blueprint tab. If it was active, activates another.
  void closeBlueprint(String id) {
    if (!_docs.containsKey(id)) return;
    final wasActive = id == _activeId;
    _docs.remove(id);
    _hub.fire(BlueprintClosed(id));
    if (_docs.isEmpty) {
      // Always keep one tab around.
      final nid = _openNewBlueprintInternal(
        title: 'Blueprint ${++_bpCounter}',
        makeActive: true,
        fireEvents: true,
      );
      // ensure listeners see an initial state for the new tab
      _hub.fire(TabGraphChanged(nid, _docs[nid]!.graph));
      _hub.fire(GraphChanged(_docs[nid]!.graph)); // legacy
      return;
    }
    if (wasActive) {
      _activeId = _docs.keys.first;
      // Do not fire GraphChanged here – switching tabs shouldn’t rebuild
      // graph-bound widgets unless the graph itself changed.
      _hub.fire(ActiveBlueprintChanged(_activeId));
    }
  }

  /// Switch active blueprint tab.
  void activateBlueprint(String id) {
    if (!_docs.containsKey(id) || id == _activeId) return;
    _activeId = id;
    _hub.fire(ActiveBlueprintChanged(id));
  }

  /// Rename a tab (no IO side-effects).
  void renameBlueprint(String id, String newTitle) {
    final d = _docs[id];
    if (d == null) return;
    d.title = newTitle;
    _hub.fire(BlueprintRenamed(id, newTitle));
  }

  // ───────────────── internal helpers ─────────────────
  String _openNewBlueprintInternal({
    required String title,
    required bool makeActive,
    required bool fireEvents,
  }) {
    final id = _id();
    _docs[id] = _Doc(graph: Graph.empty(), title: title);
    if (makeActive) _activeId = id;
    if (fireEvents) {
      _hub.fire(BlueprintOpened(id, title));
      if (makeActive) _hub.fire(ActiveBlueprintChanged(_activeId));
      // prime stacked canvases for this tab
      _hub.fire(TabGraphChanged(id, _docs[id]!.graph));
      if (makeActive) _hub.fire(GraphChanged(_doc.graph)); // legacy
    }
    return id;
  }
}
