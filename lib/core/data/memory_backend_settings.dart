part of 'memory_backend.dart';

/// Settings, sync metadata, image cache, saved
/// layouts, search history, and reminder methods
/// for [MemoryBackend].
mixin _MemorySettingsMixin on _MemoryStorage {
  // ── Sources ───────────────────────────────────

  Future<List<Map<String, dynamic>>> getSources() async {
    final list = sources.values.toList();
    list.sort(
      (a, b) => ((a['sort_order'] as int?) ?? 0).compareTo(
        (b['sort_order'] as int?) ?? 0,
      ),
    );
    return list;
  }

  Future<Map<String, dynamic>?> getSource(String id) async => sources[id];

  Future<void> saveSource(Map<String, dynamic> source) async {
    sources[source['id'] as String] = source;
  }

  Future<void> deleteSource(String id) async {
    sources.remove(id);
    // Cascade-delete content belonging to this source.
    channels.removeWhere((_, c) => c['source_id'] == id);
    vodItems.removeWhere((_, v) => v['source_id'] == id);
    epg.removeWhere((_, entries) {
      entries.removeWhere((e) => e['source_id'] == id);
      return entries.isEmpty;
    });
    categories.removeWhere((key, _) => key.startsWith('$id:'));
    syncTimes.remove(id);
  }

  Future<void> reorderSources(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final src = sources[ids[i]];
      if (src != null) {
        src['sort_order'] = i;
      }
    }
  }

  Future<void> updateSourceSyncStatus(
    String id,
    String status, {
    String? error,
    int? syncTimeMs,
  }) async {
    final src = sources[id];
    if (src == null) return;
    src['last_sync_status'] = status;
    src['last_sync_error'] = error;
    if (syncTimeMs != null) {
      src['last_sync_time'] =
          DateTime.fromMillisecondsSinceEpoch(syncTimeMs).toIso8601String();
    }
  }

  Future<String> getSourceStats() async {
    final stats = <Map<String, dynamic>>[];
    final allIds = <String>{};
    for (final c in channels.values) {
      final sid = c['source_id'] as String?;
      if (sid != null) allIds.add(sid);
    }
    for (final v in vodItems.values) {
      final sid = v['source_id'] as String?;
      if (sid != null) allIds.add(sid);
    }
    for (final sid in allIds) {
      final chCount =
          channels.values.where((c) => c['source_id'] == sid).length;
      final vodCount =
          vodItems.values.where((v) => v['source_id'] == sid).length;
      stats.add({
        'source_id': sid,
        'channel_count': chCount,
        'vod_count': vodCount,
      });
    }
    stats.sort(
      (a, b) => (a['source_id'] as String).compareTo(b['source_id'] as String),
    );
    return jsonEncode(stats);
  }

  // ── Settings ───────────────────────────────────

  Future<String?> getSetting(String key) async => settings[key];

  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  Future<void> removeSetting(String key) async {
    settings.remove(key);
  }

  // ── Sync Metadata ─────────────────────────────

  Future<int?> getLastSyncTime(String sourceId) async => syncTimes[sourceId];

  Future<void> setLastSyncTime(String sourceId, int timestamp) async {
    syncTimes[sourceId] = timestamp;
  }

  // ── Image Cache ────────────────────────────────

  String _imgKey(String id, String kind) => '$id:$kind';

  Future<String?> getCachedImageUrl(String itemId, String imageKind) async =>
      imageCache[_imgKey(itemId, imageKind)];

  Future<void> setCachedImageUrl(Map<String, dynamic> entry) async {
    final id = entry['item_id'] as String;
    final kind = entry['image_kind'] as String;
    final url = entry['image_url'] as String;
    imageCache[_imgKey(id, kind)] = url;
  }

  Future<void> clearImageCache() async => imageCache.clear();

  Future<Map<String, String>> getAllCachedImageUrls(String imageKind) async {
    final result = <String, String>{};
    for (final e in imageCache.entries) {
      if (e.key.endsWith(':$imageKind')) {
        final itemId = e.key.substring(0, e.key.length - imageKind.length - 1);
        result[itemId] = e.value;
      }
    }
    return result;
  }

  Future<void> removeCachedImage(String itemId, String imageKind) async {
    imageCache.remove(_imgKey(itemId, imageKind));
  }

  // ── Saved Layouts ──────────────────────────────

  Future<List<Map<String, dynamic>>> loadSavedLayouts() async =>
      savedLayouts.values.toList();

  Future<void> saveSavedLayout(Map<String, dynamic> layout) async {
    savedLayouts[layout['id'] as String] = layout;
  }

  Future<void> deleteSavedLayout(String id) async {
    savedLayouts.remove(id);
  }

  Future<Map<String, dynamic>?> getSavedLayoutById(String id) async =>
      savedLayouts[id];

  // ── Search History ─────────────────────────────

  Future<List<Map<String, dynamic>>> loadSearchHistory() async =>
      searchHistory.values.toList();

  Future<void> saveSearchEntry(Map<String, dynamic> entry) async {
    searchHistory[entry['id'] as String] = entry;
  }

  Future<void> deleteSearchEntry(String id) async {
    searchHistory.remove(id);
  }

  Future<void> clearSearchHistory() async => searchHistory.clear();

  Future<int> deleteSearchByQuery(String query) async {
    final lowerQ = query.toLowerCase();
    final toRemove =
        searchHistory.keys.where((id) {
          final e = searchHistory[id]!;
          final q = (e['query'] as String?)?.toLowerCase();
          return q == lowerQ;
        }).toList();
    for (final id in toRemove) {
      searchHistory.remove(id);
    }
    return toRemove.length;
  }

  // ── Reminders ──────────────────────────────────

  Future<List<Map<String, dynamic>>> loadReminders() async =>
      reminders.values.toList();

  Future<void> saveReminder(Map<String, dynamic> reminder) async {
    reminders[reminder['id'] as String] = reminder;
  }

  Future<void> deleteReminder(String id) async {
    reminders.remove(id);
  }

  Future<void> clearFiredReminders() async {
    reminders.removeWhere((_, v) => v['fired'] == true);
  }

  Future<void> markReminderFired(String id) async {
    final reminder = reminders[id];
    if (reminder != null) {
      reminder['fired'] = true;
    }
  }

  // ── Bookmarks ──────────────────────────────────

  Future<List<Map<String, dynamic>>> loadBookmarks(String contentId) async {
    return bookmarks.values.where((b) => b['content_id'] == contentId).toList();
  }

  Future<void> saveBookmark(Map<String, dynamic> bookmark) async {
    bookmarks[bookmark['id'] as String] = bookmark;
  }

  Future<void> deleteBookmark(String id) async {
    bookmarks.remove(id);
  }

  Future<void> clearBookmarks(String contentId) async {
    bookmarks.removeWhere((_, v) => v['content_id'] == contentId);
  }

  // ── Smart Groups ─────────────────────────────────

  Future<String> createSmartGroup(String name) async {
    final id = 'sg-${DateTime.now().microsecondsSinceEpoch}';
    smartGroups[id] = {
      'id': id,
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    smartGroupMembers[id] = [];
    return id;
  }

  Future<void> deleteSmartGroup(String groupId) async {
    smartGroups.remove(groupId);
    smartGroupMembers.remove(groupId);
  }

  Future<void> renameSmartGroup(String groupId, String name) async {
    final g = smartGroups[groupId];
    if (g != null) g['name'] = name;
  }

  Future<void> addSmartGroupMember(
    String groupId,
    String channelId,
    String sourceId,
    int priority,
  ) async {
    final members = smartGroupMembers.putIfAbsent(groupId, () => []);
    members.removeWhere((m) => m['channel_id'] == channelId);
    members.add({
      'group_id': groupId,
      'channel_id': channelId,
      'source_id': sourceId,
      'priority': priority,
    });
  }

  Future<void> removeSmartGroupMember(String groupId, String channelId) async {
    smartGroupMembers[groupId]?.removeWhere(
      (m) => m['channel_id'] == channelId,
    );
  }

  Future<void> reorderSmartGroupMembers(
    String groupId,
    String orderedChannelIdsJson,
  ) async {
    final ids = (jsonDecode(orderedChannelIdsJson) as List).cast<String>();
    final members = smartGroupMembers[groupId];
    if (members == null) return;
    for (var i = 0; i < ids.length; i++) {
      final m = members.firstWhere(
        (m) => m['channel_id'] == ids[i],
        orElse: () => <String, dynamic>{},
      );
      if (m.isNotEmpty) m['priority'] = i;
    }
  }

  Future<String> getSmartGroupsJson() async {
    final result = <Map<String, dynamic>>[];
    for (final g in smartGroups.values) {
      final members = smartGroupMembers[g['id']] ?? [];
      final sorted = List<Map<String, dynamic>>.from(
        members,
      )..sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
      result.add({...g, 'members': sorted});
    }
    return jsonEncode(result);
  }

  Future<String?> getSmartGroupForChannel(String channelId) async {
    for (final entry in smartGroupMembers.entries) {
      for (final m in entry.value) {
        if (m['channel_id'] == channelId) {
          final group = smartGroups[entry.key];
          return group != null ? jsonEncode(group) : null;
        }
      }
    }
    return null;
  }

  Future<String> getSmartGroupAlternatives(String channelId) async {
    // Find which group this channel belongs to.
    String? groupId;
    String? sourceId;
    for (final entry in smartGroupMembers.entries) {
      for (final m in entry.value) {
        if (m['channel_id'] == channelId) {
          groupId = entry.key;
          sourceId = m['source_id'] as String?;
          break;
        }
      }
      if (groupId != null) break;
    }
    if (groupId == null) return '[]';
    final members = smartGroupMembers[groupId] ?? [];
    final alts =
        members
            .where(
              (m) => m['channel_id'] != channelId && m['source_id'] != sourceId,
            )
            .toList();
    return jsonEncode(alts);
  }

  Future<String> detectSmartGroupCandidates() async {
    // Simplified: return empty candidates for testing.
    return '[]';
  }
}
