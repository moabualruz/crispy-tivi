import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/providers/source_filter_provider.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../data/epg_json_codec.dart';
import 'epg_state.dart';

export 'epg_state.dart';

/// Manages EPG grid state.
class EpgNotifier extends Notifier<EpgState> {
  static const _viewportHalfWindow = Duration(hours: 3);

  /// Max channels per EPG fetch. Set high for initial load to catch
  /// all channels with EPG data; the Rust facade efficiently filters
  /// via SQL. The UI grid virtualizes — only visible rows render.
  static const _viewportChannelLimit = 500;
  static const _retentionBuffer = Duration(hours: 1);

  bool _hasViewportFetch = false;

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
    final tvgIndex = buildEpgTvgIndex(channels);
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
    final tvgIndex = buildEpgTvgIndex(channels);
    state = state.copyWith(
      channels: channels,
      epgOverrides: epgOverrides,
      tvgIdIndex: tvgIndex,
      isLoading: false,
    );
  }

  List<Channel> _viewportChannels() {
    final filteredChannels = state.filteredChannels;
    if (filteredChannels.isEmpty) return const [];

    final selectedChannelId = state.selectedChannel;
    if (selectedChannelId == null) {
      return filteredChannels.take(_viewportChannelLimit).toList();
    }

    final selectedIndex = filteredChannels.indexWhere(
      (channel) => channel.id == selectedChannelId,
    );
    if (selectedIndex < 0) {
      return filteredChannels.take(_viewportChannelLimit).toList();
    }

    final halfWindow = _viewportChannelLimit ~/ 2;
    final start = math.max(0, selectedIndex - halfWindow);
    final end = math.min(
      filteredChannels.length,
      start + _viewportChannelLimit,
    );
    final adjustedStart = math.max(0, end - _viewportChannelLimit);
    return filteredChannels.sublist(adjustedStart, end);
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

  Future<void> _ensureChannelsLoaded() async {
    if (state.channels.isNotEmpty) return;

    final cache = ref.read(cacheServiceProvider);
    final sourceIds = ref.read(effectiveSourceIdsProvider);
    final channels = await cache.getChannelsPage(
      sourceIds: sourceIds,
      sort: 'name_asc',
      offset: 0,
      limit: _viewportChannelLimit,
    );
    final selectedChannelId = state.selectedChannel;
    if (selectedChannelId != null &&
        channels.every((channel) => channel.id != selectedChannelId)) {
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

  Future<void> _refreshViewportAroundFocus() async {
    final anchor = state.focusedTime ?? DateTime.now();
    final start = anchor.subtract(_viewportHalfWindow);
    final end = anchor.add(_viewportHalfWindow);
    await fetchEpgWindow(start, end);
  }

  /// Fetches EPG for currently filtered channels within ±3h of focus.
  Future<void> fetchEpgWindow(
    DateTime requestedStart,
    DateTime requestedEnd,
  ) async {
    await _ensureChannelsLoaded();

    final requestedDuration = requestedEnd.difference(requestedStart);
    final anchor = state.focusedTime ?? DateTime.now();
    final start = anchor.subtract(_viewportHalfWindow);
    final end = anchor.add(_viewportHalfWindow);
    final channelsToFetch = _viewportChannels();
    if (channelsToFetch.isEmpty) return;

    _hasViewportFetch = true;
    state = state.copyWith(isLoading: true);

    final channelIds = channelsToFetch.map((c) => c.id).toSet().toList();
    final retainedKeys = _retainedEntryKeys(channelsToFetch);

    try {
      final cache = ref.read(cacheServiceProvider);
      if (requestedDuration > const Duration(hours: 6)) {
        debugPrint(
          'EpgNotifier: clamping wide EPG request '
          '(${requestedDuration.inHours}h) to viewport window',
        );
      }

      // Use the 3-layer facade: L1 hot cache → L2 SQLite → L3 per-channel API.
      // Always clamp to the active viewport so the guide stays lazy and bounded.
      final newEntries = await cache.getChannelsEpg(channelIds, start, end);

      // Serialize both maps to the Rust epoch-ms format, merge via backend.
      final backend = ref.read(crispyBackendProvider);
      final existingJson = EpgJsonCodec.encode(state.entries);
      final newJson = EpgJsonCodec.encode(newEntries);
      final mergedJson = await backend.mergeEpgWindow(existingJson, newJson);
      final merged = EpgJsonCodec.decode(mergedJson);

      // Evict entries outside the retention window to bound memory.
      // Run after merge so dedup has both old and new data.
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
    await _refreshViewportAroundFocus();
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
    if (_hasViewportFetch) {
      unawaited(_refreshViewportAroundFocus());
    }
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
      unawaited(_refreshViewportAroundFocus());
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
