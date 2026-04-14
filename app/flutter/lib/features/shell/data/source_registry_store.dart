import 'source_registry_store_stub.dart'
    if (dart.library.io) 'source_registry_store_io.dart'
    if (dart.library.html) 'source_registry_store_web.dart';

abstract class SourceRegistryStore {
  const SourceRegistryStore();

  Future<String?> load();

  Future<void> save(String source);
}

SourceRegistryStore createSourceRegistryStore() {
  return createSourceRegistryStoreImpl();
}
