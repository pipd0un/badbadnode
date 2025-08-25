// lib/src/page_api.dart
//
// Public API surface for custom page embedding.
//
// This file exposes a tiny set of functions/types so host apps and plugins can:
//  • register a renderer for a page "kind"
//  • open a new tab that renders such a page
//  • (optionally) mark an existing tab id as a page
//
// Usage example (app/plugin side):
//
//   // 1) Register the 'bible' renderer once (e.g., during plugin init):
//   registerPageRenderer('bible', (context, ref, ctx) {
//     return BibleEditor(path: ctx.data['path'] as String);
//   });
//
//   // 2) Open as a tab when user clicks `script/bible.yaml`:
//   openPageTab(
//     title: 'bible.yaml',
//     kind: 'bible',
//     data: {'path': 'script/bible.yaml'},
//   );

import 'services/page_embedder.dart'
    show PageBuilder, PageEmbedder;

/// Re-export the context & builder typedef for convenience.
export 'services/page_embedder.dart' show PageBuilder, PageTabContext;

/// Register a renderer for a page [kind].
void registerPageRenderer(String kind, PageBuilder builder) {
  PageEmbedder.instance.registerKind(kind, builder);
}

/// Unregister a renderer for a page [kind].
void unregisterPageRenderer(String kind) {
  PageEmbedder.instance.unregisterKind(kind);
}

/// Open a tab that will render a page of [kind] with [title] and optional [data].
/// Returns the created tab id.
String openPageTab({
  required String title,
  required String kind,
  Map<String, dynamic>? data,
  bool activate = true,
}) {
  return PageEmbedder.instance.openPageTab(
    title: title,
    kind: kind,
    data: data,
    activate: activate,
  );
}

/// Mark an existing tab id as a page of [kind] (advanced).
void markTabAsPage({
  required String tabId,
  required String kind,
  Map<String, dynamic>? data,
}) {
  PageEmbedder.instance.markExistingTabAsPage(
    tabId: tabId,
    kind: kind,
    data: data,
  );
}
