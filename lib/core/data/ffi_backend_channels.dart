part of 'ffi_backend.dart';

/// Channel-related FFI calls.
mixin _FfiChannelsMixin on _FfiBackendBase {
  // ── Channels ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadChannels() async {
    final json = await rust_api.loadChannels();
    return _decodeJsonList(json);
  }

  Future<int> saveChannels(List<Map<String, dynamic>> channels) async {
    final result = await rust_api.saveChannels(json: jsonEncode(channels));
    return result.toInt();
  }

  Future<List<Map<String, dynamic>>> getChannelsByIds(List<String> ids) async {
    final json = await rust_api.getChannelsByIds(ids: ids);
    return _decodeJsonList(json);
  }

  Future<int> deleteRemovedChannels(
    String sourceId,
    List<String> keepIds,
  ) async {
    final result = await rust_api.deleteRemovedChannels(
      sourceId: sourceId,
      keepIds: keepIds,
    );
    return result.toInt();
  }

  Future<List<Map<String, dynamic>>> getChannelsBySources(
    List<String> sourceIds,
  ) async {
    final json = await rust_api.getChannelsBySources(
      sourceIdsJson: jsonEncode(sourceIds),
    );
    return _decodeJsonList(json);
  }

  // ── Channel Favorites ────────────────────────────

  Future<List<String>> getFavorites(String profileId) =>
      rust_api.getFavorites(profileId: profileId);

  Future<void> addFavorite(String profileId, String channelId) =>
      rust_api.addFavorite(profileId: profileId, channelId: channelId);

  Future<void> removeFavorite(String profileId, String channelId) =>
      rust_api.removeFavorite(profileId: profileId, channelId: channelId);

  // ── Categories ───────────────────────────────────

  Future<Map<String, List<String>>> loadCategories() async {
    final json = await rust_api.loadCategories();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, (value as List).cast<String>()),
    );
  }

  Future<void> saveCategories(Map<String, List<String>> categories) =>
      rust_api.saveCategories(json: jsonEncode(categories));

  Future<Map<String, List<String>>> getCategoriesBySources(
    List<String> sourceIds,
  ) async {
    final json = await rust_api.getCategoriesBySources(
      sourceIdsJson: jsonEncode(sourceIds),
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, (value as List).cast<String>()),
    );
  }

  // ── Category Favorites ───────────────────────────

  Future<List<String>> getFavoriteCategories(
    String profileId,
    String categoryType,
  ) => rust_api.getFavoriteCategories(
    profileId: profileId,
    categoryType: categoryType,
  );

  Future<void> addFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) => rust_api.addFavoriteCategory(
    profileId: profileId,
    categoryType: categoryType,
    categoryName: categoryName,
  );

  Future<void> removeFavoriteCategory(
    String profileId,
    String categoryType,
    String categoryName,
  ) => rust_api.removeFavoriteCategory(
    profileId: profileId,
    categoryType: categoryType,
    categoryName: categoryName,
  );

  // ── Channel Order ────────────────────────────────

  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  ) => rust_api.saveChannelOrder(
    profileId: profileId,
    groupName: groupName,
    channelIds: channelIds,
  );

  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  ) async {
    final json = await rust_api.loadChannelOrder(
      profileId: profileId,
      groupName: groupName,
    );
    if (json == null) return null;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    // Use (v as num).toInt() to safely handle both int and BigInt
    // values that FRB may return for integer fields.
    return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
  }

  Future<void> resetChannelOrder(String profileId, String groupName) =>
      rust_api.resetChannelOrder(profileId: profileId, groupName: groupName);

  // ── Channel Sorting ────────────────────────────

  Future<String> sortChannelsJson(String channelsJson) =>
      rust_api.sortChannelsJson(json: channelsJson);

  // ── Channel Categories ─────────────────────────

  Future<String> resolveChannelCategories(
    String channelsJson,
    String catMapJson,
  ) => rust_api.resolveChannelCategories(
    channelsJson: channelsJson,
    catMapJson: catMapJson,
  );

  Future<List<String>> extractSortedGroups(String channelsJson) =>
      rust_api.extractSortedGroups(channelsJson: channelsJson);

  // ── Duplicate Detection ────────────────────────

  Future<String?> findGroupForChannel(String groupsJson, String channelId) =>
      rust_api.findGroupForChannel(
        groupsJson: groupsJson,
        channelId: channelId,
      );

  bool isDuplicate(String groupsJson, String channelId) =>
      rust_api.isDuplicate(groupsJson: groupsJson, channelId: channelId);

  Future<List<String>> getAllDuplicateIds(String groupsJson) =>
      rust_api.getAllDuplicateIds(groupsJson: groupsJson);

  // ── Channel Algorithms ─────────────────────────

  String normalizeChannelName(String name) =>
      rust_api.normalizeChannelName(name: name);

  String normalizeStreamUrl(String url) =>
      rust_api.normalizeStreamUrl(url: url);

  Future<List<Map<String, dynamic>>> detectDuplicateChannels(
    String channelsJson,
  ) async {
    final json = await rust_api.detectDuplicateChannels(json: channelsJson);
    return _decodeJsonList(json);
  }

  Future<Map<String, dynamic>> matchEpgToChannels({
    required String entriesJson,
    required String channelsJson,
    required String displayNamesJson,
  }) async {
    final json = await rust_api.matchEpgToChannels(
      entriesJson: entriesJson,
      channelsJson: channelsJson,
      displayNamesJson: displayNamesJson,
    );
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<String> matchEpgWithConfidence({
    required String entriesJson,
    required String channelsJson,
    required String displayNamesJson,
  }) async {
    return rust_api.matchEpgWithConfidence(
      entriesJson: entriesJson,
      channelsJson: channelsJson,
      displayNamesJson: displayNamesJson,
    );
  }

  Future<String?> buildCatchupUrl({
    required String channelJson,
    required int startUtc,
    required int endUtc,
  }) async {
    return rust_api.buildCatchupUrl(
      channelJson: channelJson,
      startUtc: PlatformInt64Util.from(startUtc),
      endUtc: PlatformInt64Util.from(endUtc),
    );
  }
}
