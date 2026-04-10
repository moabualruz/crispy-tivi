import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/providers/source_filter_provider.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../data/epg_json_codec.dart';
import 'epg_state.dart';

export 'epg_state.dart';

/// Manages EPG grid state.
class EpgNotifier extends Notifier<EpgState> {
  static const _viewportHalfWindow = Duration(hours: 3);
  static const _retentionBuffer = Duration(hours: 1);
  static const _initialVisibleChannelCount = 24;

  bool _hasViewportFetch = false;
  List<String> _visibleChannelIds = const [];
  Timer? _coverageRefreshDebounce;
  Timer? _visibleEntriesRefreshDebounce;

  @override
  EpgState build() {
    ref.onDispose(() {
      _coverageRefreshDebounce?.cancel();
      _visibleEntriesRefreshDebounce?.cancel();
    });
    return const EpgState();
  }

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
    final tvgIndex = buildEpgTvgIndex(channels);
    state = state.copyWith(
      channels: channels,
      entries: entries,
      channelsWithRealEpg: entries.keys.toSet(),
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
    final tvgIndex = buildEpgTvgIndex(channels);
    state = state.copyWith(
      channels: channels,
      epgOverrides: epgOverrides,
      tvgIdIndex: tvgIndex,
      isLoading: false,
    );
  }

  Set<String> _retainedEntryKeys(List<Channel> channels) {
    final keys = <String>{};
    for (final channel in channels) {
      keys.add(state.epgOverrides[channel.id] ?? channel.id);
      final tvgId = state.tvgIdIndex[channel.id];
      if (tvgId != null && tvgId.isNotEmpty) {
        keys.add(tvgId);
      }
    }
    return keys;
  }

  List<Channel> _groupFilteredChannels(EpgState currentState) {
    final selectedGroup = currentState.selectedGroup;
    if (selectedGroup == null) return currentState.channels;
    return currentState.channels
        .where((channel) => channel.group == selectedGroup)
        .toList(growable: false);
  }

  List<Channel> _visibleChannelsFor(List<Channel> channels) {
    if (channels.isEmpty) return const [];
    if (_visibleChannelIds.isEmpty) {
      return channels.take(_initialVisibleChannelCount).toList(growable: false);
    }

    final ids = _visibleChannelIds.toSet();
    final visible = channels
        .where((channel) => ids.contains(channel.id))
        .toList(growable: false);
    if (visible.isNotEmpty) return visible;
    return channels.take(_initialVisibleChannelCount).toList(growable: false);
  }

  void _scheduleCoverageRefresh() {
    _coverageRefreshDebounce?.cancel();
    _coverageRefreshDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!_hasViewportFetch) return;
      unawaited(_refreshViewportAroundFocus(refreshCoverage: true));
    });
  }

  void _scheduleVisibleEntriesRefresh() {
    _visibleEntriesRefreshDebounce?.cancel();
    _visibleEntriesRefreshDebounce = Timer(
      const Duration(milliseconds: 80),
      () {
        if (!_hasViewportFetch) return;
        unawaited(_refreshViewportAroundFocus(refreshCoverage: false));
      },
    );
  }

  Future<void> _ensureChannelsLoaded() async {
    if (state.channels.isNotEmpty) return;

    final seededChannels = ref.read(channelListProvider).channels;
    final channels =
        seededChannels.isNotEmpty
            ? List<Channel>.of(seededChannels)
            : await (() async {
              final cache = ref.read(cacheServiceProvider);
              final sourceIds = ref.read(effectiveSourceIdsProvider);
              return sourceIds.isEmpty
                  ? cache.loadChannels()
                  : cache.getChannelsBySources(sourceIds);
            })();
    final selectedChannelId = state.selectedChannel;
    if (selectedChannelId != null &&
        channels.every((channel) => channel.id != selectedChannelId)) {
      final cache = ref.read(cacheServiceProvider);
      final selectedChannel = await cache.getChannelById(selectedChannelId);
      if (selectedChannel != null) {
        channels.insert(0, selectedChannel);
      }
    }
    if (channels.isEmpty) return;

    debugPrint(
      'EpgNotifier: seeded ${channels.length} channels without bulk loading',
    );
    final overrides = state.epgOverrides;
    updateChannels(channels: channels, epgOverrides: overrides);
  }

  Future<void> _refreshViewportAroundFocus({
    required bool refreshCoverage,
  }) async {
    final anchor = state.focusedTime ?? DateTime.now();
    final start = anchor.subtract(_viewportHalfWindow);
    final end = anchor.add(_viewportHalfWindow);
    await fetchEpgWindow(start, end, refreshCoverage: refreshCoverage);
  }

  Future<void> _refreshCoverageForWindow(
    CacheService cache,
    DateTime start,
    DateTime end,
  ) async {
    final baseChannels = _groupFilteredChannels(state);
    if (baseChannels.isEmpty) {
      state = state.copyWith(
        channelsWithRealEpg: const <String>{},
        entries: const {},
        isLoading: false,
        clearError: true,
      );
      return;
    }

    final coverageIds = await cache.getEpgCoverageChannelIds(
      baseChannels.map((channel) => channel.id).toList(growable: false),
      start,
      end,
    );
    state = state.copyWith(
      channelsWithRealEpg: coverageIds.toSet(),
      isLoading: true,
    );
  }

  Future<void> _refreshVisibleEntriesForWindow(
    CacheService cache,
    DateTime start,
    DateTime end,
  ) async {
    final coveredIds = state.channelsWithRealEpg;
    if (state.showEpgOnly && coveredIds.isEmpty) {
      state = state.copyWith(
        entries: const {},
        isLoading: false,
        clearError: true,
      );
      return;
    }

    final visibleChannels = _visibleChannelsFor(state.filteredChannels);
    if (visibleChannels.isEmpty) {
      state = state.copyWith(
        entries: const {},
        isLoading: false,
        clearError: true,
      );
      return;
    }

    final channelsToFetch = visibleChannels
        .where((channel) => coveredIds.contains(channel.id))
        .toList(growable: false);
    if (channelsToFetch.isEmpty) {
      state = state.copyWith(
        entries: const {},
        isLoading: false,
        clearError: true,
      );
      return;
    }

    final channelIds = channelsToFetch
        .map((channel) => channel.id)
        .toList(growable: false);
    final retainedKeys = _retainedEntryKeys(channelsToFetch);

    // Guide scrolling must stay local and bounded.
    // Do not let viewport updates escalate into on-demand upstream fetches.
    final newEntries = await cache.getEpgsForChannels(channelIds, start, end);

    final backend = ref.read(crispyBackendProvider);
    final existingJson = EpgJsonCodec.encode(state.entries);
    final newJson = EpgJsonCodec.encode(newEntries);
    final mergedJson = await backend.mergeEpgWindow(existingJson, newJson);
    final merged = EpgJsonCodec.decode(mergedJson);

    final retentionStart = start.subtract(_retentionBuffer);
    final retentionEnd = end.add(_retentionBuffer);
    final trimmed = <String, List<EpgEntry>>{};
    for (final entry in merged.entries) {
      if (!retainedKeys.contains(entry.key)) continue;
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
  }

  /// Fetches EPG for currently filtered channels within ±3h of focus.
  Future<void> fetchEpgWindow(
    DateTime requestedStart,
    DateTime requestedEnd, {
    bool refreshCoverage = true,
  }) async {
    await _ensureChannelsLoaded();

    final requestedDuration = requestedEnd.difference(requestedStart);
    final anchor = state.focusedTime ?? DateTime.now();
    final start = anchor.subtract(_viewportHalfWindow);
    final end = anchor.add(_viewportHalfWindow);

    _hasViewportFetch = true;
    state = state.copyWith(isLoading: true);

    try {
      final cache = ref.read(cacheServiceProvider);
      if (requestedDuration > const Duration(hours: 6)) {
        debugPrint(
          'EpgNotifier: clamping wide EPG request '
          '(${requestedDuration.inHours}h) to viewport window',
        );
      }
      if (refreshCoverage) {
        await _refreshCoverageForWindow(cache, start, end);
      }
      await _refreshVisibleEntriesForWindow(cache, start, end);
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
    if (state.channels.isEmpty || !_hasViewportFetch) return;
    await _refreshViewportAroundFocus(refreshCoverage: true);
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
    state =
        entry == null
            ? state.copyWith(clearSelectedEntry: true)
            : state.copyWith(selectedEntry: entry);
  }

  /// Filter by group (null = show all).
  void selectGroup(String? group) {
    state =
        group == null
            ? state.copyWith(clearGroup: true)
            : state.copyWith(selectedGroup: group);
    if (_hasViewportFetch) {
      _scheduleCoverageRefresh();
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
    if (_hasViewportFetch) {
      _scheduleCoverageRefresh();
    }
  }

  /// Updates the current Guide viewport channel IDs.
  ///
  /// The Guide should only fetch program rows for these channels;
  /// filter coverage is resolved separately through lightweight coverage
  /// queries so toggling "EPG only" does not require full-grid EPG loads.
  void setVisibleChannelIds(List<String> channelIds) {
    if (channelIds.isEmpty) return;
    if (listEquals(_visibleChannelIds, channelIds)) return;
    _visibleChannelIds = List.unmodifiable(channelIds);
    if (_hasViewportFetch) {
      _scheduleVisibleEntriesRefresh();
    }
  }
}

/// Global EPG state provider.
final epgProvider = NotifierProvider<EpgNotifier, EpgState>(EpgNotifier.new);
