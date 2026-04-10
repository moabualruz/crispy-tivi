import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'iptv_service_providers.dart';
import 'channel_providers.dart' show channelListProvider;
import '../../domain/entities/channel.dart';
import '../../domain/entities/duplicate_group.dart';

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

    final channelsJson = encodeChannelsJson(channels);

    final results = await _backend.detectDuplicateChannels(channelsJson);

    return results.map((m) {
      final streamUrl = m['stream_url'] as String? ?? '';
      final channelIds =
          (m['channel_ids'] as List<dynamic>?)?.cast<String>() ?? [];
      return DuplicateGroup(streamUrl: streamUrl, channelIds: channelIds);
    }).toList();
  }

  /// Find the group containing a channel, if any,
  /// via the Rust backend.
  Future<DuplicateGroup?> findGroupForChannel(
    String channelId,
    List<DuplicateGroup> groups,
  ) async {
    if (groups.isEmpty) return null;
    final json = encodeDuplicateGroups(groups);
    final result = await _backend.findGroupForChannel(json, channelId);
    return decodeDuplicateGroup(result);
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

/// Provider for checking if a specific channel is a
/// duplicate.
///
/// Reads from [channelListProvider] so the UI uses the
/// same duplicate-ID state that powers filtering.
final isChannelDuplicateProvider = Provider.family.autoDispose<bool, String>((
  ref,
  channelId,
) {
  return ref.watch(
    channelListProvider.select(
      (state) => state.duplicateIds.contains(channelId),
    ),
  );
});

/// Provider for the total number of duplicate
/// channels.
final duplicateCountProvider = Provider<int>((ref) {
  return ref.watch(
    channelListProvider.select((state) => state.duplicateIds.length),
  );
});
