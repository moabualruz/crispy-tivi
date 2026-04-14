import 'package:crispy_tivi/features/shell/data/live_tv_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:flutter/services.dart';

class AssetLiveTvRuntimeRepository extends LiveTvRuntimeRepository {
  const AssetLiveTvRuntimeRepository();

  static const String assetPath = 'assets/contracts/asset_live_tv_runtime.json';

  @override
  Future<LiveTvRuntimeSnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return LiveTvRuntimeSnapshot.fromJsonString(source);
  }
}
