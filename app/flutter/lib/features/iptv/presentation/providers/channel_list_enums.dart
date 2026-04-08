import '../../domain/entities/channel.dart';

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

/// Default channel sort: by number (nulls last), then alphabetically.
///
/// Extracted as a package-private top-level helper so both the
/// [filterAndSortChannels] function and [ChannelListState] can share it.
int defaultChannelSort(Channel a, Channel b) {
  if (a.number != null && b.number != null) {
    return a.number!.compareTo(b.number!);
  }
  if (a.number != null) return -1;
  if (b.number != null) return 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

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
  String favoritesGroup = '\u2B50 Favorites',
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
  if (selectedGroup == favoritesGroup) {
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
              return defaultChannelSort(a, b);
            });
      } else {
        result = result.toList()..sort(defaultChannelSort);
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
            return defaultChannelSort(a, b);
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
            return defaultChannelSort(a, b);
          });
    case ChannelSortMode.defaultOrder:
      result = result.toList()..sort(defaultChannelSort);
  }

  return result;
}
