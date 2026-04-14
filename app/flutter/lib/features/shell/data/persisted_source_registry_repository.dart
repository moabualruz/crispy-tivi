import 'package:crispy_tivi/features/shell/data/asset_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_store.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';

class PersistedSourceRegistryRepository extends SourceRegistryRepository {
  PersistedSourceRegistryRepository({
    AssetSourceRegistryRepository? defaultsRepository,
    SourceRegistryStore? store,
  }) : defaultsRepository =
           defaultsRepository ?? const AssetSourceRegistryRepository(),
       store = store ?? createSourceRegistryStore();

  final AssetSourceRegistryRepository defaultsRepository;
  final SourceRegistryStore store;

  @override
  Future<SourceRegistrySnapshot> load() async {
    final SourceRegistrySnapshot defaults = await defaultsRepository.load();
    final String? persisted = await store.load();
    if (persisted == null || persisted.trim().isEmpty) {
      return defaults.copyWith(configuredProviders: const <SourceProviderEntry>[]);
    }
    try {
      final SourceRegistrySnapshot snapshot =
          SourceRegistrySnapshot.fromJsonString(persisted);
      return defaults.copyWith(
        selectedProviderKind: snapshot.selectedProviderKind,
        activeWizardStep: snapshot.activeWizardStep,
        configuredProviders: snapshot.configuredProviders,
      );
    } catch (_) {
      return defaults.copyWith(configuredProviders: const <SourceProviderEntry>[]);
    }
  }

  @override
  Future<void> save(SourceRegistrySnapshot snapshot) {
    return store.save(snapshot.toJsonString());
  }
}
