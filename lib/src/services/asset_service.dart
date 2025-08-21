// lib/services/asset_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// Select all asset files from
/// FilePicker without using dart:io, regardless of Web/Mobile, and return the PlatformFile list.
class AssetService {
  static const _exts = <String>{'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'mp4', 'webm', 'mov', 'mkv', 'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'};

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
      withData: true,
    );
    return result?.files ?? const [];
  }
}
