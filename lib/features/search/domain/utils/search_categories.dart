/// Builds a sorted, deduplicated list of search category strings
/// from VOD items and IPTV channel group names.
///
/// [vodCategories] is an iterable of nullable VOD category strings
/// (e.g. `vodItems.map((i) => i.category)`).
/// [channelGroups] is the list of IPTV group names
/// (e.g. `channelState.groups`).
///
/// Empty and null entries are silently skipped.
List<String> buildSearchCategories(
  Iterable<String?> vodCategories,
  Iterable<String> channelGroups,
) {
  final categories = <String>{};

  for (final cat in vodCategories) {
    if (cat != null && cat.isNotEmpty) categories.add(cat);
  }

  for (final group in channelGroups) {
    if (group.isNotEmpty) categories.add(group);
  }

  return categories.toList()..sort();
}
