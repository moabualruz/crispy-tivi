import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/data/dart_algorithm_fallbacks.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../data/epg_json_codec.dart';

/// EPG display mode.
enum EpgViewMode {
  /// Single day view (24 hours).
  day,

  /// Week view (7 days).
  week,
}

/// EPG grid state.
class EpgState {
  const EpgState({
    this.channels = const [],
    this.entries = const {},
    this.epgOverrides = const {},
    this.tvgIdIndex = const {},
    this.focusedTime,
    this.selectedChannel,
    this.selectedEntry,
    this.selectedGroup,
    this.showEpgOnly = false,
    this.viewMode = EpgViewMode.day,
    this.isLoading = false,
    this.error,
    this.lastFetchMessage,
    this.lastFetchSuccess,
  });

  /// Channels to show in the grid.
  final List<Channel> channels;

  /// EPG entries keyed by channel ID.
  final Map<String, List<EpgEntry>> entries;

  /// Manual EPG assignment overrides (channelId → targetId).
  final Map<String, String> epgOverrides;

  /// Reverse index: internal channel ID → tvg_id (XMLTV ID).
  final Map<String, String> tvgIdIndex;

  /// Currently focused time slot (for cursor navigation).
  final DateTime? focusedTime;

  /// Currently selected channel.
  final String? selectedChannel;

  /// Currently focused EPG entry (shown in info panel).
  final EpgEntry? selectedEntry;

  /// Active group/category filter (null = all).
  final String? selectedGroup;

  /// When true, only show channels that have EPG data.
  final bool showEpgOnly;

  /// Current view mode (day or week).
  final EpgViewMode viewMode;

  final bool isLoading;
  final String? error;

  /// Transient message from last EPG fetch (consumed by UI for snackbar).
  final String? lastFetchMessage;

  /// Whether last fetch was successful (null = no fetch yet).
  final bool? lastFetchSuccess;

  /// Unique group names extracted from channels.
  List<String> get groups {
    final g =
        channels
            .map((c) => c.group)
            .where((g) => g != null && g.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort(categoryBucketCompare);
    return g;
  }

  /// Channels filtered by selected group and EPG
  /// availability.
  List<Channel> get filteredChannels {
    var result = channels;
    if (selectedGroup != null) {
      result = result.where((c) => c.group == selectedGroup).toList();
    }
    if (showEpgOnly) {
      result =
          result.where((c) {
            final effectiveId = epgOverrides[c.id] ?? c.id;
            final channelEntries = entries[effectiveId];
            if (channelEntries == null || channelEntries.isEmpty) return false;
            // Exclude channels with ONLY placeholder entries.
            // Placeholders have sourceId == '_placeholder'.
            return channelEntries
                .any((e) => e.sourceId != '_placeholder');
          }).toList();
    }
    return result;
  }

  /// Returns entries for a specific channel.
  ///
  /// Checks [epgOverrides] first — if the channel has a
  /// manual EPG assignment, returns entries for the target.
  List<EpgEntry> entriesForChannel(String channelId) {
    final effectiveId = epgOverrides[channelId] ?? channelId;
    final direct = entries[effectiveId];
    if (direct != null && direct.isNotEmpty) return direct;
    final tvgId = tvgIdIndex[channelId];
    if (tvgId != null && tvgId.isNotEmpty) {
      return entries[tvgId] ?? const [];
    }
    return const [];
  }

  /// Returns the currently-live EPG entry for [channelId],
  /// or null if nothing is live.
  ///
  /// Pass [now] to override the clock (deterministic tests).
  ///
  /// T-25: canonical instance method. Prefer this over the
  /// top-level [getNowPlaying] helper in epg_state_helpers.dart.
  EpgEntry? getNowPlaying(String channelId, {DateTime? now}) {
    for (final e in entriesForChannel(channelId)) {
      if (e.isLiveAt(now)) return e;
    }
    return null;
  }

  /// Alias for [getNowPlaying] — kept for backwards compatibility.
  @Deprecated('Use getNowPlaying instead')
  EpgEntry? nowPlayingFor(String channelId, {DateTime? now}) =>
      getNowPlaying(channelId, now: now);

  /// Returns the next EPG entry that starts after the
  /// currently-live programme for [channelId].
  ///
  /// Returns `null` when there is no live programme or no
  /// entry follows it in the loaded window.
  ///
  /// Pass [now] to override the clock (deterministic tests).
  EpgEntry? getNextProgram(String channelId, {DateTime? now}) {
    final live = getNowPlaying(channelId, now: now);
    if (live == null) return null;
    final all = entriesForChannel(channelId);
    for (final e in all) {
      if (e.startTime.isAfter(live.startTime) &&
          !e.startTime.isBefore(live.endTime)) {
        return e;
      }
    }
    return null;
  }

  /// Returns up to [count] upcoming entries after the
  /// currently-live programme for [channelId].
  ///
  /// The list is sorted by start time ascending and may
  /// contain fewer than [count] items when the loaded window
  /// does not have enough programmes.
  ///
  /// Pass [now] to override the clock (deterministic tests).
  List<EpgEntry> getUpcomingPrograms(
    String channelId, {
    int count = 2,
    DateTime? now,
  }) {
    final live = getNowPlaying(channelId, now: now);
    if (live == null) return const [];
    final all = entriesForChannel(channelId);
    final upcoming =
        all
            .where(
              (e) =>
                  e.startTime.isAfter(live.startTime) &&
                  !e.startTime.isBefore(live.endTime),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.take(count).toList();
  }

  EpgState copyWith({
    List<Channel>? channels,
    Map<String, List<EpgEntry>>? entries,
    Map<String, String>? epgOverrides,
    Map<String, String>? tvgIdIndex,
    DateTime? focusedTime,
    String? selectedChannel,
    EpgEntry? selectedEntry,
    String? selectedGroup,
    bool? showEpgOnly,
    EpgViewMode? viewMode,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearGroup = false,
    bool clearSelectedEntry = false,
    String? lastFetchMessage,
    bool? lastFetchSuccess,
    bool clearFetchMessage = false,
  }) {
    return EpgState(
      channels: channels ?? this.channels,
      entries: entries ?? this.entries,
      epgOverrides: epgOverrides ?? this.epgOverrides,
      tvgIdIndex: tvgIdIndex ?? this.tvgIdIndex,
      focusedTime: focusedTime ?? this.focusedTime,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      selectedEntry:
          clearSelectedEntry ? null : (selectedEntry ?? this.selectedEntry),
      selectedGroup: clearGroup ? null : (selectedGroup ?? this.selectedGroup),
      showEpgOnly: showEpgOnly ?? this.showEpgOnly,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastFetchMessage:
          clearFetchMessage
              ? null
              : (lastFetchMessage ?? this.lastFetchMessage),
      lastFetchSuccess:
          clearFetchMessage
              ? null
              : (lastFetchSuccess ?? this.lastFetchSuccess),
    );
  }
}

/// Manages EPG grid state.
class EpgNotifier extends Notifier<EpgState> {
  @override
  EpgState build() => const EpgState();

  /// Load channels and optionally replace entries.
  ///
  /// EPG data is now lazy-loaded via [fetchEpgWindow].
  /// Prefer [updateChannels] when you only need to
  /// refresh channels without wiping existing entries.
  void loadData({
    required List<Channel> channels,
    Map<String, List<EpgEntry>> entries = const {},
    Map<String, String>? epgOverrides,
  }) {
    final tvgIndex = _buildTvgIndex(channels);
    state = state.copyWith(
      channels: channels,
      entries: entries,
      epgOverrides: epgOverrides,
      tvgIdIndex: tvgIndex,
      focusedTime: DateTime.now(),
      isLoading: false,
    );
  }

  /// Updates channels and overrides while preserving
  /// existing EPG entries. Use this instead of
  /// [loadData] when refreshing channel metadata
  /// without a full EPG reload.
  void updateChannels({
    required List<Channel> channels,
    Map<String, String>? epgOverrides,
  }) {
    final tvgIndex = _buildTvgIndex(channels);
    state = state.copyWith(
      channels: channels,
      epgOverrides: epgOverrides,
      tvgIdIndex: tvgIndex,
      isLoading: false,
    );
  }

  static Map<String, String> _buildTvgIndex(List<Channel> channels) {
    final idx = <String, String>{};
    for (final ch in channels) {
      final tvg = ch.tvgId;
      if (tvg != null && tvg.isNotEmpty) {
        idx[ch.id] = tvg;
      }
    }
    return idx;
  }

  /// Fetches an EPG window tailored to the currently filtered channels.
  Future<void> fetchEpgWindow(DateTime start, DateTime end) async {
    var channelsToFetch = state.channels;
    if (state.selectedGroup != null) {
      channelsToFetch =
          channelsToFetch.where((c) => c.group == state.selectedGroup).toList();
    }
    if (channelsToFetch.isEmpty) return;

    state = state.copyWith(isLoading: true);

    final channelIds =
        channelsToFetch.map((c) => state.epgOverrides[c.id] ?? c.id).toList();

    try {
      final cache = ref.read(cacheServiceProvider);
      // Use the 3-layer facade: L1 hot cache → L2 SQLite → L3 per-channel API.
      // This replaces the old bulk-only path that couldn't fetch EPG for
      // Xtream/Stalker channels with shared tvg_ids.
      final newEntries = await cache.getChannelsEpg(channelIds, start, end);

      // Serialize both maps to the Rust epoch-ms format, merge via backend.
      final backend = ref.read(crispyBackendProvider);
      final existingJson = EpgJsonCodec.encode(state.entries);
      final newJson = EpgJsonCodec.encode(newEntries);
      final mergedJson = await backend.mergeEpgWindow(existingJson, newJson);
      final merged = EpgJsonCodec.decode(mergedJson);

      // Evict entries outside the retention window to bound memory.
      // Run after merge so dedup has both old and new data.
      const retentionBuffer = Duration(hours: 4);
      final retentionStart = start.subtract(retentionBuffer);
      final retentionEnd = end.add(retentionBuffer);
      final trimmed = <String, List<EpgEntry>>{};
      for (final entry in merged.entries) {
        final kept =
            entry.value
                .where(
                  (e) =>
                      e.endTime.isAfter(retentionStart) &&
                      e.startTime.isBefore(retentionEnd),
                )
                .toList();
        if (kept.isNotEmpty) trimmed[entry.key] = kept;
      }

      state = state.copyWith(
        entries: trimmed,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (e is StateError ||
          e.toString().contains('disposed') ||
          e.toString().contains('UnmountedRefException')) {
        // The Notifier was disposed or the ref is unmounted.
        return;
      }
      debugPrint('EpgNotifier: Failed to fetch EPG window: $e');
      try {
        state = state.copyWith(isLoading: false, error: e.toString());
      } catch (_) {
        // Ignored if completely unmounted
      }
    }
  }

  /// Re-fetches EPG entries for the current time window.
  ///
  /// Called by the event-driven invalidator when
  /// [EpgUpdated] fires. Preserves channels and all
  /// UI state — only refreshes the entry map.
  Future<void> refreshEntries() async {
    if (state.channels.isEmpty) return;
    final now = state.focusedTime ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    await fetchEpgWindow(start, end);
  }

  /// Updates the EPG override map (from settings).
  void setEpgOverrides(Map<String, String> overrides) {
    state = state.copyWith(epgOverrides: overrides);
  }

  /// Updates the focused time cursor.
  void setFocusedTime(DateTime time) {
    state = state.copyWith(focusedTime: time);
  }

  /// Selects a channel.
  void selectChannel(String channelId) {
    state = state.copyWith(selectedChannel: channelId);
  }

  /// Selects an EPG entry (shown in info panel).
  void selectEntry(EpgEntry? entry) {
    if (entry == null) {
      state = state.copyWith(clearSelectedEntry: true);
    } else {
      state = state.copyWith(selectedEntry: entry);
    }
  }

  /// Filter by group (null = show all).
  void selectGroup(String? group) {
    if (group == null) {
      state = state.copyWith(clearGroup: true);
    } else {
      state = state.copyWith(selectedGroup: group);
    }
  }

  /// Sets the EPG view mode (day or week).
  void setViewMode(EpgViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// Sets loading state.
  void setLoading() {
    state = state.copyWith(isLoading: true, clearError: true);
  }

  /// Sets error state.
  void setError(String error) {
    state = state.copyWith(isLoading: false, error: error);
  }

  /// Sets fetch result message (consumed by UI for snackbar).
  void setFetchResult(String message, {bool success = true}) {
    state = state.copyWith(
      lastFetchMessage: message,
      lastFetchSuccess: success,
    );
  }

  /// Clears the fetch message after UI has consumed it.
  void clearFetchMessage() {
    state = state.copyWith(clearFetchMessage: true);
  }

  /// Toggles EPG-only channel filter.
  void toggleEpgOnly() {
    state = state.copyWith(showEpgOnly: !state.showEpgOnly);
  }
}

/// Global EPG state provider.
final epgProvider = NotifierProvider<EpgNotifier, EpgState>(EpgNotifier.new);

/// Clock function used by EPG widgets.
///
/// Returns the current time. Override in tests with a
/// fixed [DateTime] to produce deterministic goldens.
final epgClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Notifier for the EPG program search query.
class EpgProgramSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Updates the search query.
  void setQuery(String query) => state = query;

  /// Clears the search query.
  void clear() => state = '';
}

/// Current search query for the EPG program guide.
///
/// Updated by [EpgSearchDelegate] when the user types in
/// the search field. Widgets can watch this to filter or
/// highlight matching program blocks.
final epgProgramSearchProvider =
    NotifierProvider<EpgProgramSearchNotifier, String>(
      EpgProgramSearchNotifier.new,
    );
