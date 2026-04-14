import 'dart:io';

import 'personalization_runtime_store.dart';
import 'runtime_store_paths.dart';

PersonalizationRuntimeStore createPersonalizationRuntimeStoreImpl() {
  return const _IoPersonalizationRuntimeStore();
}

final class _IoPersonalizationRuntimeStore extends PersonalizationRuntimeStore {
  const _IoPersonalizationRuntimeStore();

  @override
  Future<String?> load() async {
    final File file = await _resolveFile();
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> save(String source) async {
    final File file = await _resolveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(source, flush: true);
  }

  Future<File> _resolveFile() async {
    return File(
      '${crispyConfigHome()}/crispy_tivi/personalization_runtime.json',
    );
  }
}
