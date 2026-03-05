import '../../../../config/settings_state.dart';
import '../../../iptv/domain/entities/channel.dart';

/// Sorts [channels] according to [sort].
///
/// - [FavoritesSort.recentlyAdded] — preserves original order (most
///   recent first as stored by the history service).
/// - [FavoritesSort.nameAsc] — alphabetical A → Z by channel name.
/// - [FavoritesSort.nameDesc] — alphabetical Z → A by channel name.
/// - [FavoritesSort.contentType] — grouped by [Channel.group], then
///   alphabetical within each group.
///
/// Pure function — no Flutter or framework imports.
List<Channel> sortFavorites(List<Channel> channels, FavoritesSort sort) {
  final list = List<Channel>.from(channels);
  switch (sort) {
    case FavoritesSort.recentlyAdded:
      break;
    case FavoritesSort.nameAsc:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case FavoritesSort.nameDesc:
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case FavoritesSort.contentType:
      list.sort((a, b) {
        final ga = a.group ?? '';
        final gb = b.group ?? '';
        final cmp = ga.compareTo(gb);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }
  return list;
}
