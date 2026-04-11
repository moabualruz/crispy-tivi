final class HeroFeature {
  const HeroFeature({
    required this.kicker,
    required this.title,
    required this.summary,
    required this.primaryAction,
    required this.secondaryAction,
    this.backgroundAsset,
  });

  final String kicker;
  final String title;
  final String summary;
  final String primaryAction;
  final String secondaryAction;
  final String? backgroundAsset;
}

final class ShelfItem {
  const ShelfItem({
    required this.title,
    required this.caption,
    this.rank,
    this.imageAsset,
  });

  final String title;
  final String caption;
  final int? rank;
  final String? imageAsset;
}

final class ChannelEntry {
  const ChannelEntry({
    required this.number,
    required this.name,
    required this.program,
    required this.timeRange,
  });

  final String number;
  final String name;
  final String program;
  final String timeRange;
}

final class SearchResultGroup {
  const SearchResultGroup({required this.title, required this.results});

  final String title;
  final List<ShelfItem> results;
}

final class SettingsItem {
  const SettingsItem({
    required this.title,
    required this.summary,
    required this.value,
  });

  final String title;
  final String summary;
  final String value;
}

final class SourceHealthItem {
  const SourceHealthItem({
    required this.name,
    required this.status,
    required this.summary,
  });

  final String name;
  final String status;
  final String summary;
}
