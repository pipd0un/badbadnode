// lib/src/controller/graph_controller.tabs.dart

part of 'graph_controller.core.dart';

// ───────────────── tab API (public) ─────────────────

mixin _TabsMixin on _GraphCoreBase {
  List<BlueprintTabInfo> get tabs => [
        for (final e in _docs.entries)
          BlueprintTabInfo(id: e.key, title: e.value.title),
      ];
  String get activeBlueprintId => _activeId ?? '';

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
      _activeId = null;
      // Allow a completely empty workspace (no auto-tab).
      _hub.fire(ActiveBlueprintChanged(''));
      _hub.fire(GraphChanged(Graph.empty())); // legacy listeners
      return;
    }
    if (wasActive) {
      _activeId = _docs.keys.first;
      // Do not fire GraphChanged here – switching tabs shouldn’t rebuild
      // graph-bound widgets unless the graph itself changed.
      _hub.fire(ActiveBlueprintChanged(_activeId!));
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
    final doc = _Doc(graph: Graph.empty(), title: title);
    // Seed globals when starting from an empty workspace.
    doc.globals.addAll(_seedGlobals);
    doc.globalsBootstrapped = _seedGlobalsBootstrapped;
    _docs[id] = doc;
    if (makeActive) _activeId = id;
    if (fireEvents) {
      _hub.fire(BlueprintOpened(id, title));
      if (makeActive) _hub.fire(ActiveBlueprintChanged(_activeId!));
      // prime stacked canvases for this tab
      _hub.fire(TabGraphChanged(id, _docs[id]!.graph));
      if (makeActive) _hub.fire(GraphChanged(_docs[id]!.graph)); // legacy
    }
    return id;
  }
}
