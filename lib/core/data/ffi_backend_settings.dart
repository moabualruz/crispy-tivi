part of 'ffi_backend.dart';

/// Settings-related FFI calls.
mixin _FfiSettingsMixin on _FfiBackendBase {
  // ── Settings ─────────────────────────────────────

  Future<String?> getSetting(String key) => rust_api.getSetting(key: key);

  Future<void> setSetting(String key, String value) =>
      rust_api.setSetting(key: key, value: value);

  Future<void> removeSetting(String key) => rust_api.removeSetting(key: key);

  // ── Image Cache ──────────────────────────────────
  // (Removed in Phase 10 API simplification)

  // ── Saved Layouts ────────────────────────────────

  Future<List<Map<String, dynamic>>> loadSavedLayouts() async {
    final json = await rust_api.loadSavedLayouts();
    return _decodeJsonList(json);
  }

  Future<void> saveSavedLayout(Map<String, dynamic> layout) =>
      rust_api.saveSavedLayout(json: jsonEncode(layout));

  Future<void> deleteSavedLayout(String id) =>
      rust_api.deleteSavedLayout(id: id);

  Future<Map<String, dynamic>?> getSavedLayoutById(String id) async {
    final json = await rust_api.getSavedLayoutById(id: id);
    final decoded = jsonDecode(json);
    if (decoded == null) return null;
    return decoded as Map<String, dynamic>;
  }

  // ── Search History ───────────────────────────────

  Future<List<Map<String, dynamic>>> loadSearchHistory() async {
    final json = await rust_api.loadSearchHistory();
    return _decodeJsonList(json);
  }

  Future<void> saveSearchEntry(Map<String, dynamic> entry) =>
      rust_api.saveSearchEntry(json: jsonEncode(entry));

  Future<void> deleteSearchEntry(String id) =>
      rust_api.deleteSearchEntry(id: id);

  Future<void> clearSearchHistory() => rust_api.clearSearchHistory();

  Future<int> deleteSearchByQuery(String query) async {
    final result = await rust_api.deleteSearchByQuery(query: query);
    return result.toInt();
  }

  // ── Maintenance ──────────────────────────────────

  Future<void> clearAll() => rust_api.clearAll();

  // ── Phase 8: Watch History Service ───────────────

  Future<int> clearAllWatchHistory() async {
    final result = await rust_api.clearAllWatchHistory();
    return result.toInt();
  }

  // ── Normalize ──────────────────────────────────

  bool validateMacAddress(String mac) => rust_api.validateMacAddress(mac: mac);

  String macToDeviceId(String mac) => rust_api.macToDeviceId(mac: mac);

  List<String> guessLogoDomains(String name) =>
      rust_api.guessLogoDomains(name: name);
}
