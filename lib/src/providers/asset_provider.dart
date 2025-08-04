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