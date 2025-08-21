// lib/providers/asset_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../services/asset_service.dart' show AssetService;
import '../services/asset_service.dart' show AssetHub, AssetMeta;

/// Service provider (still available for legacy toolbar actions or host apps)
final assetServiceProvider = Provider<AssetService>((ref) => AssetService());

/// Canonical provider of currently available assets (as PlatformFile),
/// now **kept in sync with panel-published assets via AssetHub**.
///
/// IMPORTANT:
///   • This notifier mirrors `AssetHub.instance.assets` automatically.
///   • Nodes that were reading `assetFilesProvider` (pre panel-integration)
///     continue to work without changes.
///   • Toolbar mount/unmount is no longer required.
final assetFilesProvider =
    StateNotifierProvider<AssetFilesNotifier, List<PlatformFile>>(
  (ref) => AssetFilesNotifier(ref),
);

class AssetFilesNotifier extends StateNotifier<List<PlatformFile>> {
  AssetFilesNotifier(this.ref) : super(const []) {
    // Seed from current panel snapshot.
    _syncFromHub(AssetHub.instance.assets);
    // Keep mirrored with panel changes.
    _sub = AssetHub.instance.changes.listen(_syncFromHub);
    ref.onDispose(() => _sub?.cancel());
  }

  final Ref ref;
  StreamSubscription<List<AssetMeta>>? _sub;

  void _syncFromHub(List<AssetMeta> metas) {
    // Normalize to PlatformFile for maximum backward-compatibility.
    state = [
      for (final m in metas)
        PlatformFile(
          name: m.fileName,
          path: m.path,
          size: m.size ?? (m.bytes?.length ?? 0),
          bytes: m.bytes, // ← CRITICAL for Flutter Web images
        ),
    ];
  }

  /// Legacy helper (still usable by host apps): pick assets via FilePicker.
  /// NOTE: Using this will NOT bypass the panel; it only sets provider state.
  /// Prefer publishing through the panel (which already updates AssetHub).
  Future<void> loadAssets() async {
    final files = await ref.read(assetServiceProvider).pickAllAssets();
    state = files;
  }

  void clear() => state = const [];
}