// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'personalization_runtime_store.dart';

PersonalizationRuntimeStore createPersonalizationRuntimeStoreImpl() {
  return const _WebPersonalizationRuntimeStore();
}

final class _WebPersonalizationRuntimeStore
    extends PersonalizationRuntimeStore {
  const _WebPersonalizationRuntimeStore();

  static const String _key = 'crispy_tivi.personalization_runtime';

  @override
  Future<String?> load() async {
    return html.window.localStorage[_key];
  }

  @override
  Future<void> save(String source) async {
    html.window.localStorage[_key] = source;
  }
}
