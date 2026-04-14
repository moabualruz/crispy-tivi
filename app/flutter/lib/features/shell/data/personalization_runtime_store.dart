import 'personalization_runtime_store_stub.dart'
    if (dart.library.io) 'personalization_runtime_store_io.dart'
    if (dart.library.html) 'personalization_runtime_store_web.dart';

abstract class PersonalizationRuntimeStore {
  const PersonalizationRuntimeStore();

  Future<String?> load();

  Future<void> save(String source);
}

PersonalizationRuntimeStore createPersonalizationRuntimeStore() {
  return createPersonalizationRuntimeStoreImpl();
}
