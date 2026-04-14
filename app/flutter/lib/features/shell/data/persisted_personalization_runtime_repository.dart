import 'package:crispy_tivi/features/shell/data/asset_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_store.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';

class PersistedPersonalizationRuntimeRepository
    extends PersonalizationRuntimeRepository {
  PersistedPersonalizationRuntimeRepository({
    this.seedDefaults = false,
    AssetPersonalizationRuntimeRepository? defaultsRepository,
    PersonalizationRuntimeStore? store,
  }) : defaultsRepository =
           defaultsRepository ?? AssetPersonalizationRuntimeRepository(),
       store = store ?? createPersonalizationRuntimeStore();

  final bool seedDefaults;
  final AssetPersonalizationRuntimeRepository defaultsRepository;
  final PersonalizationRuntimeStore store;

  @override
  Future<PersonalizationRuntimeSnapshot> load() async {
    final PersonalizationRuntimeSnapshot defaults =
        seedDefaults
            ? await defaultsRepository.load()
            : const PersonalizationRuntimeSnapshot.empty();
    final String? persisted = await store.load();
    if (persisted == null || persisted.trim().isEmpty) {
      return defaults;
    }
    try {
      return PersonalizationRuntimeSnapshot.fromJsonString(persisted);
    } catch (_) {
      return defaults;
    }
  }

  @override
  Future<void> save(PersonalizationRuntimeSnapshot snapshot) {
    return store.save(snapshot.toJsonString());
  }
}
