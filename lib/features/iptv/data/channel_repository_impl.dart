import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';

export '../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, crispyBackendProvider;
import '../domain/entities/channel.dart';
import '../domain/entities/epg_entry.dart';
import '../domain/repositories/channel_repository.dart';

/// CacheService-backed implementation of [ChannelRepository].
class ChannelRepositoryImpl implements ChannelRepository {
  ChannelRepositoryImpl(this._cache);

  final CacheService _cache;

  // ── Channels ───────────────────────────────────────

  @override
  Future<void> saveChannels(List<Channel> channels) =>
      _cache.saveChannels(channels);

  @override
  Future<List<Channel>> loadChannels() => _cache.loadChannels();

  @override
  Future<List<Channel>> getChannelsByIds(List<String> ids) =>
      _cache.getChannelsByIds(ids);

  @override
  Future<List<Channel>> getChannelsBySources(List<String> sourceIds) =>
      _cache.getChannelsBySources(sourceIds);

  @override
  Future<Map<String, List<String>>> getCategoriesBySources(
    List<String> sourceIds,
  ) => _cache.getCategoriesBySources(sourceIds);

  @override
  Future<int> deleteRemovedChannels(String sourceId, Set<String> keepIds) =>
      _cache.deleteRemovedChannels(sourceId, keepIds);

  // ── EPG ────────────────────────────────────────────

  @override
  Future<Map<String, List<EpgEntry>>> getEpgsForChannels(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) => _cache.getEpgsForChannels(channelIds, start, end);

  @override
  Future<Map<String, List<EpgEntry>>> getChannelsEpg(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) => _cache.getChannelsEpg(channelIds, start, end);

  @override
  Future<void> saveEpgEntries(Map<String, List<EpgEntry>> entriesByChannel) =>
      _cache.saveEpgEntries(entriesByChannel);

  @override
  Future<Map<String, List<EpgEntry>>> loadEpgEntries() =>
      _cache.loadEpgEntries();

  @override
  Future<int> evictStaleEpgEntries({int days = 2}) =>
      _cache.evictStaleEpgEntries(days: days);

  @override
  Future<void> clearEpgEntries() => _cache.clearEpgEntries();

  // ── EPG Mappings ────────────────────────────────────

  @override
  Future<void> saveEpgMapping(Map<String, dynamic> mapping) =>
      _cache.saveEpgMapping(mapping);

  @override
  Future<List<Map<String, dynamic>>> getEpgMappings() =>
      _cache.getEpgMappings();

  @override
  Future<void> lockEpgMapping(String channelId) =>
      _cache.lockEpgMapping(channelId);

  @override
  Future<void> deleteEpgMapping(String channelId) =>
      _cache.deleteEpgMapping(channelId);

  @override
  Future<List<Map<String, dynamic>>> getPendingEpgSuggestions() =>
      _cache.getPendingEpgSuggestions();

  @override
  Future<void> setChannel247(String channelId, {required bool is247}) =>
      _cache.setChannel247(channelId, is247: is247);

  // ── Channel Ordering ────────────────────────────────

  @override
  Future<List<String>> extractSortedGroups(List<Channel> channels) =>
      _cache.extractSortedGroups(channels);

  @override
  Future<void> saveChannelOrder(
    String profileId,
    String groupName,
    List<String> channelIds,
  ) => _cache.saveChannelOrder(profileId, groupName, channelIds);

  @override
  Future<Map<String, int>?> loadChannelOrder(
    String profileId,
    String groupName,
  ) => _cache.loadChannelOrder(profileId, groupName);

  @override
  Future<void> resetChannelOrder(String profileId, String groupName) =>
      _cache.resetChannelOrder(profileId, groupName);

  // ── EPG-aware Search ───────────────────────────────

  @override
  Future<List<String>> searchChannelsByLiveProgram(
    Map<String, List<EpgEntry>> epgEntries,
    String query,
    int nowMs,
  ) => _cache.searchChannelsByLiveProgram(epgEntries, query, nowMs);

  @override
  Future<List<Channel>> mergeEpgMatchedChannels({
    required List<Channel> baseChannels,
    required List<Channel> allChannels,
    required List<String> matchedIds,
    required Map<String, String> epgOverrides,
  }) => _cache.mergeEpgMatchedChannels(
    baseChannels: baseChannels,
    allChannels: allChannels,
    matchedIds: matchedIds,
    epgOverrides: epgOverrides,
  );

  // ── Smart Groups ────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getSmartGroupsParsed() =>
      _cache.getSmartGroupsParsed();

  @override
  Future<List<Map<String, dynamic>>> getSmartGroupCandidatesParsed() =>
      _cache.getSmartGroupCandidatesParsed();
}

/// Riverpod provider for [ChannelRepository].
final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepositoryImpl(ref.watch(cacheServiceProvider));
});
