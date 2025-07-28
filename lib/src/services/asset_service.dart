// lib/services/asset_service.dart
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// Select all asset files from
/// FilePicker without using dart:io, regardless of Web/Mobile, and return the PlatformFile list.
class AssetService {
  /// Prompts the user to select multiple files.
  /// Allowed extensions: .png, .jpg, .jpg, .mp4, .mp3
  Future<List<PlatformFile>> pickAllAssets() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'mp4', 'mp3'],
      withData: kIsWeb, // Get bytes on the web too
    );
    return result?.files ?? [];
  }
}
