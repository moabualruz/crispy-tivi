import 'package:flutter/painting.dart';

import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';

enum ArtworkSourceKind { asset, network }

final class ArtworkSource {
  const ArtworkSource.asset(this.value) : kind = ArtworkSourceKind.asset;
  const ArtworkSource.network(this.value) : kind = ArtworkSourceKind.network;

  final ArtworkSourceKind kind;
  final String value;

  ImageProvider<Object> provider() {
    return switch (kind) {
      ArtworkSourceKind.asset => AssetImage(value),
      ArtworkSourceKind.network => NetworkImage(value),
    };
  }
}

final class HeroFeature {
  const HeroFeature({
    required this.kicker,
    required this.title,
    required this.summary,
    required this.primaryAction,
    required this.secondaryAction,
    this.artwork,
  });

  final String kicker;
  final String title;
  final String summary;
  final String primaryAction;
  final String secondaryAction;
  final ArtworkSource? artwork;
}

final class ShelfItem {
  const ShelfItem({
    required this.title,
    required this.caption,
    this.rank,
    this.artwork,
  });

  final String title;
  final String caption;
  final int? rank;
  final ArtworkSource? artwork;
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
    required this.sourceType,
    required this.endpoint,
    required this.lastSync,
    required this.capabilities,
    required this.primaryAction,
  });

  final String name;
  final String status;
  final String summary;
  final String sourceType;
  final String endpoint;
  final String lastSync;
  final List<String> capabilities;
  final String primaryAction;
}

final class SourceWizardStepContent {
  const SourceWizardStepContent({
    required this.step,
    required this.title,
    required this.summary,
    required this.primaryAction,
    required this.secondaryAction,
    required this.fieldLabels,
    required this.helperLines,
  });

  final SourceWizardStep step;
  final String title;
  final String summary;
  final String primaryAction;
  final String secondaryAction;
  final List<String> fieldLabels;
  final List<String> helperLines;
}
