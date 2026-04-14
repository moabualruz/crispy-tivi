import 'package:crispy_tivi/features/shell/data/search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:flutter/services.dart';

class AssetSearchRuntimeRepository extends SearchRuntimeRepository {
  const AssetSearchRuntimeRepository();

  static const String assetPath = 'assets/contracts/asset_search_runtime.json';

  @override
  Future<SearchRuntimeSnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return SearchRuntimeSnapshot.fromJsonString(source);
  }
}
