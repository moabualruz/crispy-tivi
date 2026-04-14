import 'source_registry_store.dart';

SourceRegistryStore createSourceRegistryStoreImpl() {
  return const _NoopSourceRegistryStore();
}

final class _NoopSourceRegistryStore extends SourceRegistryStore {
  const _NoopSourceRegistryStore();

  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String source) async {}
}
