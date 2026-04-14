import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:flutter/services.dart';

class AssetSourceRegistryRepository extends SourceRegistryRepository {
  const AssetSourceRegistryRepository();

  static const String assetPath = 'assets/contracts/asset_source_registry.json';

  @override
  Future<SourceRegistrySnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return SourceRegistrySnapshot.fromJsonString(source);
  }

  @override
  Future<void> save(SourceRegistrySnapshot snapshot) async {}
}
