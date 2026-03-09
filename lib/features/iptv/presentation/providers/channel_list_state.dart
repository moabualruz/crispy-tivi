import '../../domain/entities/channel.dart';

/// Filters and sorts [channels] according to the given parameters.
///
/// This is a pure top-level function with no dependency on
/// [ChannelListState], making it directly unit-testable.
///
/// Exclusion passes (in order):
/// 1. Hidden groups ([hiddenGroups])
/// 2. Hidden/blocked channel IDs ([hiddenChannelIds])
///    — skipped when [showHiddenChannels] is true
/// 3. Duplicate IDs ([duplicateIds]) when [hideDuplicates] is true
/// 4. Group filter ([selectedGroup] / [groupMode])
/// 5. Search predicate ([searchQuery])
///
/// Then applies the chosen [sortMode].
List<Channel> filterAndSortChannels(
  List<Channel> channels, {
  required String searchQuery,
  required ChannelSortMode sortMode,
  required ChannelGroupMode groupMode,
  String? selectedGroup,
  Set<String> hiddenGroups = const {},
  Set<String> hiddenChannelIds = const {},
  bool hideDuplicates = false,
  Set<String> duplicateIds = const {},
  Map<String, int>? customOrderMap,
  Map<String, String> sourceNames = const {},
  Map<String, DateTime> lastWatchedMap = const {},
  bool showHiddenChannels = false,
}) {
  var result = channels;

  // 1. Exclude hidden groups.
  if (hiddenGroups.isNotEmpty) {
    result = result.where((c) => !hiddenGroups.contains(c.group)).toList();
  }

  // 2. Exclude individually hidden/blocked channels.
  // When [showHiddenChannels] is true the user has explicitly toggled
  // "Show Hidden" so we reveal them (useful for un-hiding).
  if (hiddenChannelIds.isNotEmpty && !showHiddenChannels) {
    result = result.where((c) => !hiddenChannelIds.contains(c.id)).toList();
  }

  // 3. Exclude duplicate channels if enabled.
  if (hideDuplicates && duplicateIds.isNotEmpty) {
    result = result.where((c) => !duplicateIds.contains(c.id)).toList();
  }

  // 4. Group filter.
  if (selectedGroup == ChannelListState.favoritesGroup) {
    result = result.where((c) => c.isFavorite).toList();
  } else if (selectedGroup != null) {
    if (groupMode == ChannelGroupMode.byPlaylist) {
      // Resolve display name back to source ID.
      final sourceId =
          sourceNames.entries
              .where((e) => e.value == selectedGroup)
              .map((e) => e.key)
              .firstOrNull;
      final id = sourceId ?? selectedGroup;
      result = result.where((c) => c.sourceId == id).toList();
    } else {
      result = result.where((c) => c.group == selectedGroup).toList();
    }
  }

  // 5. Search predicate.
  if (searchQuery.isNotEmpty) {
    final query = searchQuery.toLowerCase();
    result =
        result
            .where(
              (c) =>
                  c.name.toLowerCase().contains(query) ||
                  (c.group?.toLowerCase().contains(query) ?? false),
            )
            .toList();
  }

  // Apply sort based on mode.
  switch (sortMode) {
    case ChannelSortMode.manual:
      if (customOrderMap != null && customOrderMap.isNotEmpty) {
        result =
            result.toList()..sort((a, b) {
              final aOrder = customOrderMap[a.id];
              final bOrder = customOrderMap[b.id];
              if (aOrder != null && bOrder != null) {
                return aOrder.compareTo(bOrder);
              }
              if (aOrder != null) return -1;
              if (bOrder != null) return 1;
              return _defaultChannelSort(a, b);
            });
      } else {
        result = result.toList()..sort(_defaultChannelSort);
      }
    case ChannelSortMode.byName:
      result =
          result.toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    case ChannelSortMode.byDateAdded:
      result =
          result.toList()..sort((a, b) {
            final aDate = a.addedAt;
            final bDate = b.addedAt;
            if (aDate != null && bDate != null) {
              return bDate.compareTo(aDate);
            }
            if (aDate != null) return -1;
            if (bDate != null) return 1;
            return _defaultChannelSort(a, b);
          });
    case ChannelSortMode.byWatchTime:
      result =
          result.toList()..sort((a, b) {
            final aTime = lastWatchedMap[a.id];
            final bTime = lastWatchedMap[b.id];
            if (aTime != null && bTime != null) {
              return bTime.compareTo(aTime);
            }
            if (aTime != null) return -1;
            if (bTime != null) return 1;
            return _defaultChannelSort(a, b);
          });
    case ChannelSortMode.defaultOrder:
      result = result.toList()..sort(_defaultChannelSort);
  }

  return result;
}

/// Default channel sort: by number (nulls last), then alphabetically.
///
/// Extracted as a package-private top-level helper so both the
/// [filterAndSortChannels] function and [ChannelListState] can share it.
int _defaultChannelSort(Channel a, Channel b) {
  if (a.number != null && b.number != null) {
    return a.number!.compareTo(b.number!);
  }
  if (a.number != null) return -1;
  if (b.number != null) return 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// How channels are grouped in the list.
enum ChannelGroupMode {
  /// Group by M3U category/group tag.
  byCategory,

  /// Group by playlist source (multi-source).
  byPlaylist,
}

/// Channel sort mode options.
enum ChannelSortMode {
  /// Default: by order in playlist
  /// (number, then name).
  defaultOrder,

  /// Alphabetical by channel name (A-Z).
  byName,

  /// Most recently added first.
  byDateAdded,

  /// Most recently watched first.
  byWatchTime,

  /// Manual drag-to-reorder (uses custom order map).
  manual,
}

/// State for the channel list, managed by
/// [channelListProvider].
class ChannelListState {
  const ChannelListState({
    this.channels = const [],
    this.groups = const [],
    this.hiddenGroups = const {},
    this.hiddenChannelIds = const {},
    this.selectedGroup,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.customOrderMap,
    this.isReorderMode = false,
    this.hideDuplicates = false,
    this.duplicateIds = const {},
    this.showingGroupsView = true,
    this.sortMode = ChannelSortMode.defaultOrder,
    this.groupMode = ChannelGroupMode.byCategory,
    this.sourceNames = const {},
    this.lastWatchedMap = const {},
    this.showHiddenChannels = false,
    this.filteredChannelsCache,
  });

  static const favoritesGroup = '\u2B50 Favorites';

  final List<Channel> channels;
  final List<String> groups;
  final Set<String> hiddenGroups;

  /// Individual channel IDs hidden or blocked
  /// by the user.
  final Set<String> hiddenChannelIds;
  final String? selectedGroup;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  /// Custom sort order map (channelId -> sortIndex).
  /// Null means use default sort (number, then name).
  final Map<String, int>? customOrderMap;

  /// Whether reorder mode is active
  /// (shows drag handles).
  final bool isReorderMode;

  /// Whether to hide duplicate channels from
  /// the list.
  final bool hideDuplicates;

  /// Set of channel IDs that are duplicates
  /// (not preferred).
  final Set<String> duplicateIds;

  /// Whether the groups list view is showing
  /// (mobile only). When true, shows the groups
  /// list. When false, shows channels.
  final bool showingGroupsView;

  /// Current sort mode for channels.
  final ChannelSortMode sortMode;

  /// How channels are grouped
  /// (by category or by playlist).
  final ChannelGroupMode groupMode;

  /// Playlist source ID -> display name map.
  final Map<String, String> sourceNames;

  /// Channel ID -> last watched timestamp
  /// (for sort by watch time).
  final Map<String, DateTime> lastWatchedMap;

  /// When `true`, hidden/blocked channels are included in the
  /// filtered list so users can review and un-hide them.
  ///
  /// Toggled via the sort menu ("Show Hidden Channels").
  /// Does not persist across sessions — resets to `false` on
  /// restart. Spec: FE-TV-04.
  final bool showHiddenChannels;

  /// Pre-computed filtered + sorted channel list.
  ///
  /// Eagerly cached on every [copyWith] to avoid
  /// recomputing O(n) filter+sort on every widget
  /// read. Falls back to computing on-the-fly
  /// if null.
  final List<Channel>? filteredChannelsCache;

  /// Whether any channel is favorited.
  bool get _hasFavorites => channels.any((c) => c.isFavorite);

  /// Number of favorited channels.
  int get favoriteCount => channels.where((c) => c.isFavorite).length;

  /// Channel count per group name (key = group ?? '').
  Map<String, int> get groupCounts {
    final counts = <String, int>{};
    for (final ch in channels) {
      final g = ch.group ?? '';
      counts[g] = (counts[g] ?? 0) + 1;
    }
    return counts;
  }

  /// Groups with Favorites prepended when favorites
  /// exist, excluding hidden groups.
  ///
  /// When [groupMode] is [ChannelGroupMode.byPlaylist],
  /// returns playlist source names instead.
  List<String> get displayGroups {
    if (groupMode == ChannelGroupMode.byPlaylist) {
      final sourceIds =
          channels.map((c) => c.sourceId).whereType<String>().toSet().toList();
      final names =
          sourceIds.map((id) => sourceNames[id] ?? id).toList()..sort();
      if (_hasFavorites) {
        return [favoritesGroup, ...names];
      }
      return names;
    }

    final visible = groups.where((g) => !hiddenGroups.contains(g)).toList();
    if (_hasFavorites) {
      return [favoritesGroup, ...visible];
    }
    return visible;
  }

  /// The effective selected group — defaults to
  /// Favorites if favorites exist and no group is
  /// explicitly selected.
  String? get effectiveGroup {
    if (selectedGroup != null) return selectedGroup;
    if (_hasFavorites) return favoritesGroup;
    return null;
  }

  /// Channels filtered by current group and search
  /// query. Channels in hidden groups are excluded.
  /// Duplicates are excluded when [hideDuplicates]
  /// is true. Applies custom order if set, otherwise
  /// default sort.
  ///
  /// Uses [filteredChannelsCache] when available
  /// (eagerly computed on state change) to avoid
  /// O(n) per widget read.
  List<Channel> get filteredChannels {
    if (filteredChannelsCache != null) {
      return filteredChannelsCache!;
    }
    return _computeFilteredChannels();
  }

  /// Internal computation — called once per state
  /// change. Delegates to the pure top-level
  /// [filterAndSortChannels] function.
  List<Channel> _computeFilteredChannels() {
    return filterAndSortChannels(
      channels,
      searchQuery: searchQuery,
      sortMode: sortMode,
      groupMode: groupMode,
      selectedGroup: effectiveGroup,
      hiddenGroups: hiddenGroups,
      hiddenChannelIds: hiddenChannelIds,
      hideDuplicates: hideDuplicates,
      duplicateIds: duplicateIds,
      customOrderMap: customOrderMap,
      sourceNames: sourceNames,
      lastWatchedMap: lastWatchedMap,
      showHiddenChannels: showHiddenChannels,
    );
  }

  /// Returns a copy with [filteredChannelsCache]
  /// eagerly computed from current field values.
  ChannelListState _withComputedCache() {
    return ChannelListState(
      channels: channels,
      groups: groups,
      hiddenGroups: hiddenGroups,
      hiddenChannelIds: hiddenChannelIds,
      selectedGroup: selectedGroup,
      searchQuery: searchQuery,
      isLoading: isLoading,
      error: error,
      customOrderMap: customOrderMap,
      isReorderMode: isReorderMode,
      hideDuplicates: hideDuplicates,
      duplicateIds: duplicateIds,
      showingGroupsView: showingGroupsView,
      sortMode: sortMode,
      groupMode: groupMode,
      sourceNames: sourceNames,
      lastWatchedMap: lastWatchedMap,
      showHiddenChannels: showHiddenChannels,
      filteredChannelsCache: _computeFilteredChannels(),
    );
  }

  ChannelListState copyWith({
    List<Channel>? channels,
    List<String>? groups,
    Set<String>? hiddenGroups,
    Set<String>? hiddenChannelIds,
    String? selectedGroup,
    String? searchQuery,
    bool? isLoading,
    String? error,
    Map<String, int>? customOrderMap,
    bool? isReorderMode,
    bool? hideDuplicates,
    Set<String>? duplicateIds,
    bool? showingGroupsView,
    ChannelSortMode? sortMode,
    ChannelGroupMode? groupMode,
    Map<String, String>? sourceNames,
    Map<String, DateTime>? lastWatchedMap,
    bool? showHiddenChannels,
    bool clearGroup = false,
    bool clearError = false,
    bool clearCustomOrder = false,
  }) {
    return ChannelListState(
      channels: channels ?? this.channels,
      groups: groups ?? this.groups,
      hiddenGroups: hiddenGroups ?? this.hiddenGroups,
      hiddenChannelIds: hiddenChannelIds ?? this.hiddenChannelIds,
      selectedGroup: clearGroup ? null : (selectedGroup ?? this.selectedGroup),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      customOrderMap:
          clearCustomOrder ? null : (customOrderMap ?? this.customOrderMap),
      isReorderMode: isReorderMode ?? this.isReorderMode,
      hideDuplicates: hideDuplicates ?? this.hideDuplicates,
      duplicateIds: duplicateIds ?? this.duplicateIds,
      showingGroupsView: showingGroupsView ?? this.showingGroupsView,
      sortMode: sortMode ?? this.sortMode,
      groupMode: groupMode ?? this.groupMode,
      sourceNames: sourceNames ?? this.sourceNames,
      lastWatchedMap: lastWatchedMap ?? this.lastWatchedMap,
      showHiddenChannels: showHiddenChannels ?? this.showHiddenChannels,
    )._withComputedCache();
  }
}
