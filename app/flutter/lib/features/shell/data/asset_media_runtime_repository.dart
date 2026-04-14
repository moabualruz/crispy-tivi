import 'package:crispy_tivi/features/shell/data/media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:flutter/services.dart';

class AssetMediaRuntimeRepository extends MediaRuntimeRepository {
  const AssetMediaRuntimeRepository();

  static const String assetPath = 'assets/contracts/asset_media_runtime.json';

  @override
  Future<MediaRuntimeSnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return MediaRuntimeSnapshot.fromJsonString(source);
  }
}
