// A minimal stand-in for `package:web/web.dart` when the build target is NOT
// the browser.  It exposes the same top-level `window` identifier but with no
// behaviour, so imports stay valid and tree-shaking removes this on web.
//
// Do NOT import this directly — see the conditional import in main.dart.
class _StubWindow {
  dynamic get document => null;
}

// ignore: library_private_types_in_public_api
final _StubWindow window = _StubWindow();
