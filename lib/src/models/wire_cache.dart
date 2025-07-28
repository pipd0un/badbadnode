// lib/core/wire_cache.dart

import 'dart:ui';

/// Small helper that stores an already-constructed Path together with the
/// endpoints that produced it, so we can re-use the path until either point
/// moves.
class CachedPath {
  Path path;
  Offset from;
  Offset to;
  CachedPath(this.path, this.from, this.to);
}
