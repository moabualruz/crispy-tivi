import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/dart_algorithm_fallbacks.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';

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
            return channelEntries.any((e) => e.sourceId != '_placeholder');
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

// ─────────────────────────────────────────────────────────────
//  Clock provider (needed by widgets alongside EpgState)
// ─────────────────────────────────────────────────────────────

/// Clock function used by EPG widgets.
///
/// Returns the current time. Override in tests with a
/// fixed [DateTime] to produce deterministic goldens.
final epgClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
