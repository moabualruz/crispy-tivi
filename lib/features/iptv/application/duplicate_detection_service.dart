import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../domain/entities/channel.dart';
import '../domain/entities/duplicate_group.dart';

/// Service for detecting duplicate channels across
/// sources by delegating to the Rust backend.
///
/// Detects duplicates by comparing normalized stream
/// URLs. Channels with identical URLs are grouped
/// together.
class DuplicateDetectionService {
  DuplicateDetectionService(this._backend);

  final CrispyBackend _backend;

  /// Detect duplicate channels from a list.
  ///
  /// Serializes channels to JSON, delegates to Rust,
  /// and converts the result to [DuplicateGroup]s.
  Future<List<DuplicateGroup>> detectDuplicates(List<Channel> channels) async {
    if (channels.isEmpty) return const [];

    final json = jsonEncode(channels.map(channelToMap).toList());

    final results = await _backend.detectDuplicateChannels(json);

    return results.map((m) {
      final streamUrl = m['stream_url'] as String? ?? '';
      final channelIds =
          (m['channel_ids'] as List<dynamic>?)?.cast<String>() ?? [];
      return DuplicateGroup(streamUrl: streamUrl, channelIds: channelIds);
    }).toList();
  }

  /// Get a set of all channel IDs that are duplicates
  /// (not preferred) via the Rust backend.
  ///
  /// The first channel in each group is considered
  /// the "original", and all others are marked as
  /// duplicates.
  Future<Set<String>> getDuplicateIds(List<DuplicateGroup> groups) async {
    if (groups.isEmpty) return const {};
    final json = _encodeGroups(groups);
    final ids = await _backend.getAllDuplicateIds(json);
    return ids.toSet();
  }

  /// Check if a specific channel is a duplicate
  /// via the Rust backend.
  bool isDuplicate(String channelId, List<DuplicateGroup> groups) {
    if (groups.isEmpty) return false;
    final json = _encodeGroups(groups);
    return _backend.isDuplicate(json, channelId);
  }

  /// Find the group containing a channel, if any,
  /// via the Rust backend.
  Future<DuplicateGroup?> findGroupForChannel(
    String channelId,
    List<DuplicateGroup> groups,
  ) async {
    if (groups.isEmpty) return null;
    final json = _encodeGroups(groups);
    final result = await _backend.findGroupForChannel(json, channelId);
    if (result == null || result.isEmpty) return null;
    final m = jsonDecode(result) as Map<String, dynamic>;
    final streamUrl = m['stream_url'] as String? ?? '';
    final channelIds =
        (m['channel_ids'] as List<dynamic>?)?.cast<String>() ?? [];
    return DuplicateGroup(streamUrl: streamUrl, channelIds: channelIds);
  }

  /// Serializes [DuplicateGroup] list to JSON for
  /// the Rust backend.
  String _encodeGroups(List<DuplicateGroup> groups) {
    return jsonEncode(
      groups
          .map(
            (g) => {
              'stream_url': g.streamUrl,
              'channel_ids': g.channelIds,
              if (g.preferredId != null) 'preferred_id': g.preferredId,
            },
          )
          .toList(),
    );
  }
}

/// Provider for [DuplicateDetectionService].
final duplicateDetectionServiceProvider = Provider<DuplicateDetectionService>((
  ref,
) {
  return DuplicateDetectionService(ref.read(crispyBackendProvider));
});

/// Notifier for detected duplicate groups.
///
/// This is populated after playlist sync and can be
/// watched by UI.
class DuplicateGroupsNotifier extends Notifier<List<DuplicateGroup>> {
  @override
  List<DuplicateGroup> build() => const [];

  /// Update the duplicate groups.
  void setGroups(List<DuplicateGroup> groups) {
    state = groups;
  }

  /// Clear all duplicate groups.
  void clear() {
    state = const [];
  }
}

/// Provider for detected duplicate groups.
final duplicateGroupsProvider =
    NotifierProvider<DuplicateGroupsNotifier, List<DuplicateGroup>>(
      DuplicateGroupsNotifier.new,
    );

/// Provider for the set of duplicate channel IDs.
///
/// Derived from [duplicateGroupsProvider] for quick
/// lookup. Delegates to Rust backend.
final duplicateChannelIdsProvider = FutureProvider<Set<String>>((ref) async {
  final groups = ref.watch(duplicateGroupsProvider);
  final service = ref.watch(duplicateDetectionServiceProvider);
  return service.getDuplicateIds(groups);
});

/// Provider for checking if a specific channel is a
/// duplicate.
///
/// autoDispose: O(1) Set.contains — trivial to recompute.
final isChannelDuplicateProvider = Provider.family.autoDispose<bool, String>((
  ref,
  channelId,
) {
  final duplicateIds = ref.watch(duplicateChannelIdsProvider).value;
  if (duplicateIds == null) return false;
  return duplicateIds.contains(channelId);
});

/// Provider for the total number of duplicate
/// channels.
final duplicateCountProvider = Provider<int>((ref) {
  final duplicateIds = ref.watch(duplicateChannelIdsProvider).value;
  return duplicateIds?.length ?? 0;
});
