import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

class AssetPersonalizationRuntimeRepository
    extends PersonalizationRuntimeRepository {
  AssetPersonalizationRuntimeRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/contracts/asset_personalization_runtime.json',
  }) : bundle = bundle ?? rootBundle;

  final AssetBundle bundle;
  final String assetPath;

  @override
  Future<PersonalizationRuntimeSnapshot> load() async {
    final String source = await bundle.loadString(assetPath);
    return PersonalizationRuntimeSnapshot.fromJsonString(source);
  }

  @override
  Future<void> save(PersonalizationRuntimeSnapshot snapshot) async {
    // Asset-backed defaults are read-only.
  }
}
