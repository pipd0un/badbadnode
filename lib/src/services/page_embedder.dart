// lib/src/services/page_embedder.dart
//
// Page Embedder: lightweight registry + runtime tab management that lets the
// Host render custom pages (non-blueprint) inside normal tabs.
//
// Design goals:
// • No breaking changes to GraphController tabs or Toolbar.
// • Custom pages are opened as regular tabs (id/title) via GraphController.
// • Host detects such tabs and renders a registered builder instead of CanvasScene.
// • App/plugins can register renderers by "kind" and open tabs with arbitrary data.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller/graph_controller.core.dart' show GraphController;

/// Builder signature for a custom page embedded into a tab.
typedef PageBuilder = Widget Function(
  BuildContext context,
  WidgetRef ref,
  PageTabContext ctx,
);

/// Context passed to a page builder.
class PageTabContext {
  final String id;
  final String title; // best-effort; toolbar is the source of truth
  final String kind;
  final Map<String, dynamic> data;
  final GraphController graph;

  const PageTabContext({
    required this.id,
    required this.title,
    required this.kind,
    required this.data,
    required this.graph,
  });

  PageTabContext copyWith({
    String? id,
    String? title,
    String? kind,
    Map<String, dynamic>? data,
    GraphController? graph,
  }) {
    return PageTabContext(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      data: data ?? this.data,
      graph: graph ?? this.graph,
    );
  }
}

/// Singleton service used by Host + public page API.
class PageEmbedder {
  PageEmbedder._();
  static final PageEmbedder instance = PageEmbedder._();

  GraphController? _graph;

  /// kind → builder
  final Map<String, PageBuilder> _builders = <String, PageBuilder>{};

  /// tabId → context
  final Map<String, PageTabContext> _ctxByTabId = <String, PageTabContext>{};

  // ────────────────────────────────────────────────────────────────────────────
  // Host wiring
  // ────────────────────────────────────────────────────────────────────────────

  void attachGraph(GraphController graph) {
    _graph = graph;
  }

  void detachGraph() {
    _graph = null;
    _ctxByTabId.clear();
  }

  /// Clean up when a tab is closed.
  void onTabClosed(String tabId) {
    _ctxByTabId.remove(tabId);
  }

  /// Optional: refresh stored title if the app needs it (best-effort).
  void onTabRenamed(String tabId, String newTitle) {
    final old = _ctxByTabId[tabId];
    if (old != null) {
      _ctxByTabId[tabId] = old.copyWith(title: newTitle);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Registry
  // ────────────────────────────────────────────────────────────────────────────

  void registerKind(String kind, PageBuilder builder) {
    _builders[kind] = builder;
  }

  void unregisterKind(String kind) {
    _builders.remove(kind);
  }

  PageBuilder? builderForKind(String kind) => _builders[kind];

  // ────────────────────────────────────────────────────────────────────────────
  // Runtime API
  // ────────────────────────────────────────────────────────────────────────────

  /// Open a new tab rendering a page of [kind] using the registered builder.
  /// Returns the new tab id.
  String openPageTab({
    required String title,
    required String kind,
    Map<String, dynamic>? data,
    bool activate = true,
  }) {
    final graph = _graph;
    if (graph == null) {
      throw StateError(
        'PageEmbedder.openPageTab called before Host attached the GraphController.',
      );
    }
    // Create a normal tab via GraphController so Toolbar & events stay intact.
    final id = graph.newBlueprint();
    graph.renameBlueprint(id, title);
    if (activate) {
      graph.activateBlueprint(id);
    }

    // Track this tab as a custom page.
    _ctxByTabId[id] = PageTabContext(
      id: id,
      title: title,
      kind: kind,
      data: data ?? const <String, dynamic>{},
      graph: graph,
    );

    // Optional: leave the graph empty; the page renderer owns the content.
    return id;
  }

  /// Mark an already existing tab id as a custom page (e.g., if you made the tab yourself).
  void markExistingTabAsPage({
    required String tabId,
    required String kind,
    Map<String, dynamic>? data,
  }) {
    final graph = _graph;
    if (graph == null) return;

    // Try to discover the current title from controller tabs.
    String title = 'Untitled';
    try {
      final t = graph.tabs.firstWhere((t) => t.id == tabId);
      // ignore: unnecessary_cast
      title = (t.title as String?) ?? title;
    } catch (_) {}

    _ctxByTabId[tabId] = PageTabContext(
      id: tabId,
      title: title,
      kind: kind,
      data: data ?? const <String, dynamic>{},
      graph: graph,
    );
  }

  /// Get the page context for a tab id if it's a custom page, else null.
  PageTabContext? contextForTab(String tabId) => _ctxByTabId[tabId];

  /// Whether the given tab id is managed as a custom page.
  bool isPageTab(String tabId) => _ctxByTabId.containsKey(tabId);
}
