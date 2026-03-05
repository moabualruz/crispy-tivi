part of 'ws_backend.dart';

/// Settings-related WebSocket commands.
mixin _WsSettingsMixin on _WsBackendBase {
  // ── Sources ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSources() async {
    final data = await _send('getSources');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getSource(String id) async {
    final result = await _send('getSource', {'id': id});
    if (result == null) return null;
    return result as Map<String, dynamic>;
  }

  Future<void> saveSource(Map<String, dynamic> source) =>
      _send('saveSource', source);

  Future<void> deleteSource(String id) => _send('deleteSource', {'id': id});

  Future<void> reorderSources(List<String> ids) =>
      _send('reorderSources', {'sourceIds': ids});

  Future<void> updateSourceSyncStatus(
    String id,
    String status, {
    String? error,
    int? syncTimeMs,
  }) => _send('updateSourceSyncStatus', {
    'id': id,
    'status': status,
    if (error != null) 'error': error,
    if (syncTimeMs != null) 'syncTime': syncTimeMs ~/ 1000,
  });

  // ── Settings ─────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final data = await _send('getSetting', {'key': key});
    return data as String?;
  }

  Future<void> setSetting(String key, String value) =>
      _send('setSetting', {'key': key, 'value': value});

  Future<void> removeSetting(String key) =>
      _send('removeSetting', {'key': key});

  // ── Image Cache ──────────────────────────────
  //
  // Image cache is not persisted by the Rust server —
  // no handler exists on the WebSocket layer. These
  // methods throw so callers discover the gap
  // immediately instead of silently returning stale
  // data.

  Future<String?> getCachedImageUrl(String itemId, String imageKind) =>
      throw UnimplementedError(
        'getCachedImageUrl is not supported on WsBackend',
      );

  Future<void> setCachedImageUrl(Map<String, dynamic> entry) =>
      throw UnimplementedError(
        'setCachedImageUrl is not supported on WsBackend',
      );

  Future<void> clearImageCache() =>
      throw UnimplementedError('clearImageCache is not supported on WsBackend');

  Future<Map<String, String>> getAllCachedImageUrls(String imageKind) =>
      throw UnimplementedError(
        'getAllCachedImageUrls is not supported on WsBackend',
      );

  Future<void> removeCachedImage(String itemId, String imageKind) =>
      throw UnimplementedError(
        'removeCachedImage is not supported on WsBackend',
      );

  // ── Saved Layouts ────────────────────────────────

  Future<List<Map<String, dynamic>>> loadSavedLayouts() async {
    final data = await _send('loadSavedLayouts');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveSavedLayout(Map<String, dynamic> layout) =>
      _send('saveSavedLayout', {'layout': layout});

  Future<void> deleteSavedLayout(String id) =>
      _send('deleteSavedLayout', {'id': id});

  Future<Map<String, dynamic>?> getSavedLayoutById(String id) async {
    final result = await _send('getSavedLayoutById', {'id': id});
    if (result == null) return null;
    return result as Map<String, dynamic>;
  }

  // ── Search History ───────────────────────────────

  Future<List<Map<String, dynamic>>> loadSearchHistory() async {
    final data = await _send('loadSearchHistory');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveSearchEntry(Map<String, dynamic> entry) =>
      _send('saveSearchEntry', {'entry': entry});

  Future<void> deleteSearchEntry(String id) =>
      _send('deleteSearchEntry', {'id': id});

  Future<void> clearSearchHistory() => _send('clearSearchHistory');

  Future<int> deleteSearchByQuery(String query) async {
    final res = await _send('deleteSearchByQuery', {'query': query});
    return _countFromResult(res);
  }

  // ── Maintenance ──────────────────────────────────

  Future<void> clearAll() => _send('clearAll');

  // ── Phase 8: Watch History Service ───────────────

  Future<int> clearAllWatchHistory() async {
    final res = await _send('clearAllWatchHistory');
    return _countFromResult(res);
  }

  // ── Normalize ──────────────────────────────────

  bool validateMacAddress(String mac) {
    // Sync — local Dart fallback.
    return RegExp(kMacAddressPattern).hasMatch(mac);
  }

  String macToDeviceId(String mac) {
    // Sync — local Dart fallback.
    return mac.replaceAll(':', '');
  }

  /// Delegates to shared [dartGuessLogoDomains].
  List<String> guessLogoDomains(String name) => dartGuessLogoDomains(name);
}
