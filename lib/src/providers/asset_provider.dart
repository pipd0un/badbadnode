// lib/providers/asset_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../services/asset_service.dart' show AssetService;

final assetServiceProvider = Provider<AssetService>((ref) => AssetService());

final assetFilesProvider =
    StateNotifierProvider<AssetFilesNotifier, List<PlatformFile>>(
  (ref) => AssetFilesNotifier(ref),
);

class AssetFilesNotifier extends StateNotifier<List<PlatformFile>> {
  AssetFilesNotifier(this.ref) : super([]);

  final Ref ref;

  Future<void> loadAssets() async {
    final files = await ref.read(assetServiceProvider).pickAllAssets();
    state = files;
  }

  void clear() => state = [];
}

final backgroundProvider = Provider<List<String>>((ref) {
  return ref
      .watch(assetFilesProvider)
      .where((f) => f.name.startsWith('bg_') && f.extension == 'png')
      .map((f) => f.name)
      .toList();
});

final characterProvider = Provider<List<Map<String, String>>>((ref) {
  return ref
      .watch(assetFilesProvider)
      .where((f) => f.name.endsWith('.png') && !f.name.startsWith('bg_'))
      .map((f) => f.name.split('.').first.split('_'))
      .where((parts) => parts.length == 3)
      .map((parts) => {
            'name': parts[0][0].toUpperCase() + parts[0].substring(1),
            'cloth': parts[1][0].toUpperCase() + parts[1].substring(1),
            'state': parts[2][0].toUpperCase() + parts[2].substring(1),
            'filename': '${parts.join('_')}.png',
          })
      .toList();
});
