// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'source_registry_store.dart';

SourceRegistryStore createSourceRegistryStoreImpl() {
  return const _WebSourceRegistryStore();
}

final class _WebSourceRegistryStore extends SourceRegistryStore {
  const _WebSourceRegistryStore();

  static const String _key = 'crispy_tivi.source_registry';

  @override
  Future<String?> load() async {
    return html.window.localStorage[_key];
  }

  @override
  Future<void> save(String source) async {
    html.window.localStorage[_key] = source;
  }
}
