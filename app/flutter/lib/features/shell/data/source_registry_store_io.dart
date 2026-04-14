import 'dart:io';

import 'runtime_store_paths.dart';
import 'source_registry_store.dart';

SourceRegistryStore createSourceRegistryStoreImpl() {
  return const _IoSourceRegistryStore();
}

final class _IoSourceRegistryStore extends SourceRegistryStore {
  const _IoSourceRegistryStore();

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
    return File('${crispyConfigHome()}/crispy_tivi/source_registry.json');
  }
}
