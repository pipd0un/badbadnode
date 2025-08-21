// lib/src/services/asset_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// Select all asset files from
/// FilePicker without using dart:io, regardless of Web/Mobile, and return the PlatformFile list.
class AssetService {
  static const _exts = <String>{
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg',
    'mp4', 'webm', 'mov', 'mkv',
    'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'
  };

  Future<List<PlatformFile>> pickAllAssets() async {
    // ── Desktop / mobile: pick directory ─────────────────────────────────
    if (!kIsWeb) {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null) return const [];

      final dir = Directory(dirPath);
      if (!dir.existsSync()) return const [];

      final files = <PlatformFile>[];
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          final ext  = name.contains('.') ? name.split('.').last.toLowerCase() : '';
          if (_exts.contains(ext)) {
            files.add(
              PlatformFile(
                name: name,
                path: entity.path,
                size: entity.lengthSync(),
                // bytes left null for desktop/mobile (read from path when needed)
              ),
            );
          }
        }
      }
      return files;
    }

    // ── Web fallback: multi-file picker ─────────────────────────────────
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _exts.toList(),
      withData: true, // ← Web must include bytes
    );
    return result?.files ?? const [];
  }
}

/// Lightweight, engine-agnostic metadata descriptor for panel-published assets.
class AssetMeta {
  final String path;      // canonical path (or unique key)
  final String fileName;  // display name
  final String kind;      // "image" | "video" | "audio" | "other"
  final int? size;        // optional size in bytes (if known)
  final Uint8List? bytes; // optional raw bytes (critical for Web images)

  const AssetMeta({
    required this.path,
    required this.fileName,
    required this.kind,
    this.size,
    this.bytes,
  });

  @override
  String toString() => 'AssetMeta($kind $fileName @ $path bytes=${bytes?.length})';
}

/// Process-wide hub that panel apps can publish into,
/// and nodes/evaluator can read from.
class AssetHub {
  AssetHub._();
  static final AssetHub instance = AssetHub._();

  final _ctrl = StreamController<List<AssetMeta>>.broadcast();
  List<AssetMeta> _assets = const <AssetMeta>[];

  /// Current snapshot.
  List<AssetMeta> get assets => _assets;

  /// Stream of changes (full list each time).
  Stream<List<AssetMeta>> get changes => _ctrl.stream;

  void setAll(List<AssetMeta> items) {
    _assets = List.unmodifiable(items);
    _ctrl.add(_assets);
  }

  void clear() {
    _assets = const <AssetMeta>[];
    _ctrl.add(_assets);
  }

  void add(AssetMeta a) {
    final next = [..._assets.where((x) => x.path != a.path), a];
    _assets = List.unmodifiable(next);
    _ctrl.add(_assets);
  }

  void removeByPath(String path) {
    final next = _assets.where((x) => x.path != path).toList();
    _assets = List.unmodifiable(next);
    _ctrl.add(_assets);
  }
}
