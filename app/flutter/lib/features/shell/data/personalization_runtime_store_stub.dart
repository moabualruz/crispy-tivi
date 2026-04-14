import 'personalization_runtime_store.dart';

PersonalizationRuntimeStore createPersonalizationRuntimeStoreImpl() {
  return const _NoopPersonalizationRuntimeStore();
}

final class _NoopPersonalizationRuntimeStore
    extends PersonalizationRuntimeStore {
  const _NoopPersonalizationRuntimeStore();

  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String source) async {}
}
