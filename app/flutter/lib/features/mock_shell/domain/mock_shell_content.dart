import 'dart:convert';

import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';

class MockShellContentSnapshot {
  const MockShellContentSnapshot({
    required this.homeHero,
    required this.continueWatching,
    required this.liveNow,
    required this.movieHero,
    required this.seriesHero,
    required this.topFilms,
    required this.topSeries,
    required this.liveTvChannels,
    required this.guideRows,
    required this.searchGroups,
    required this.generalSettings,
    required this.playbackSettings,
    required this.appearanceSettings,
    required this.systemSettings,
    required this.sourceHealthItems,
    required this.sourceWizardSteps,
  });

  factory MockShellContentSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('mock shell content must be a JSON object');
    }
    return MockShellContentSnapshot.fromJson(decoded);
  }

  factory MockShellContentSnapshot.fromJson(Map<String, dynamic> json) {
    return MockShellContentSnapshot(
      homeHero: _readHeroFeature(json, 'home_hero'),
      continueWatching: _readShelfItems(json, 'continue_watching'),
      liveNow: _readShelfItems(json, 'live_now'),
      movieHero: _readHeroFeature(json, 'movie_hero'),
      seriesHero: _readHeroFeature(json, 'series_hero'),
      topFilms: _readShelfItems(json, 'top_films'),
      topSeries: _readShelfItems(json, 'top_series'),
      liveTvChannels: _readChannelEntries(json, 'live_tv_channels'),
      guideRows: _readGuideRows(json, 'guide_rows'),
      searchGroups: _readSearchGroups(json, 'search_groups'),
      generalSettings: _readSettingsItems(json, 'general_settings'),
      playbackSettings: _readSettingsItems(json, 'playback_settings'),
      appearanceSettings: _readSettingsItems(json, 'appearance_settings'),
      systemSettings: _readSettingsItems(json, 'system_settings'),
      sourceHealthItems: _readSourceHealthItems(json, 'source_health_items'),
      sourceWizardSteps: _readSourceWizardSteps(json, 'source_wizard_steps'),
    );
  }

  final HeroFeature homeHero;
  final List<ShelfItem> continueWatching;
  final List<ShelfItem> liveNow;
  final HeroFeature movieHero;
  final HeroFeature seriesHero;
  final List<ShelfItem> topFilms;
  final List<ShelfItem> topSeries;
  final List<ChannelEntry> liveTvChannels;
  final List<List<String>> guideRows;
  final List<SearchResultGroup> searchGroups;
  final List<SettingsItem> generalSettings;
  final List<SettingsItem> playbackSettings;
  final List<SettingsItem> appearanceSettings;
  final List<SettingsItem> systemSettings;
  final List<SourceHealthItem> sourceHealthItems;
  final List<SourceWizardStepContent> sourceWizardSteps;

  SourceWizardStepContent wizardStep(SourceWizardStep step) {
    return sourceWizardSteps.firstWhere(
      (SourceWizardStepContent item) => item.step == step,
      orElse:
          () =>
              throw StateError('missing source wizard step content for $step'),
    );
  }
}

HeroFeature _readHeroFeature(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  return HeroFeature(
    kicker: _readString(value, 'kicker', parent: key),
    title: _readString(value, 'title', parent: key),
    summary: _readString(value, 'summary', parent: key),
    primaryAction: _readString(value, 'primary_action', parent: key),
    secondaryAction: _readString(value, 'secondary_action', parent: key),
    artwork: _readArtworkSource(value, 'artwork', parent: key),
  );
}

List<ShelfItem> _readShelfItems(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<ShelfItem>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return ShelfItem(
            title: _readString(item, 'title', parent: key),
            caption: _readString(item, 'caption', parent: key),
            rank: _readOptionalInt(item, 'rank'),
            artwork: _readArtworkSource(item, 'artwork', parent: key),
          );
        })
        .toList(growable: false),
  );
}

List<ChannelEntry> _readChannelEntries(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<ChannelEntry>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return ChannelEntry(
            number: _readString(item, 'number', parent: key),
            name: _readString(item, 'name', parent: key),
            program: _readString(item, 'program', parent: key),
            timeRange: _readString(item, 'time_range', parent: key),
          );
        })
        .toList(growable: false),
  );
}

List<List<String>> _readGuideRows(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<List<String>>.unmodifiable(
    value
        .map((Object? row) {
          if (row is! List<Object?> || row.isEmpty) {
            throw FormatException('$key must contain only non-empty arrays');
          }
          return List<String>.unmodifiable(
            row
                .map((Object? cell) {
                  if (cell is! String || cell.isEmpty) {
                    throw FormatException(
                      '$key cells must be non-empty strings',
                    );
                  }
                  return cell;
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false),
  );
}

List<SearchResultGroup> _readSearchGroups(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<SearchResultGroup>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          final String title = _readString(item, 'title', parent: key);
          final Object? results = item['results'];
          if (results is! List<Object?> || results.isEmpty) {
            throw FormatException('$key.results must be a non-empty array');
          }
          return SearchResultGroup(
            title: title,
            results: List<ShelfItem>.unmodifiable(
              results
                  .map((Object? result) {
                    if (result is! Map<String, dynamic>) {
                      throw FormatException(
                        '$key.results must contain only objects',
                      );
                    }
                    return ShelfItem(
                      title: _readString(
                        result,
                        'title',
                        parent: '$key.results',
                      ),
                      caption: _readString(
                        result,
                        'caption',
                        parent: '$key.results',
                      ),
                      artwork: _readArtworkSource(
                        result,
                        'artwork',
                        parent: '$key.results',
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          );
        })
        .toList(growable: false),
  );
}

List<SettingsItem> _readSettingsItems(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<SettingsItem>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SettingsItem(
            title: _readString(item, 'title', parent: key),
            summary: _readString(item, 'summary', parent: key),
            value: _readString(item, 'value', parent: key),
          );
        })
        .toList(growable: false),
  );
}

List<SourceHealthItem> _readSourceHealthItems(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<SourceHealthItem>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SourceHealthItem(
            name: _readString(item, 'name', parent: key),
            status: _readString(item, 'status', parent: key),
            summary: _readString(item, 'summary', parent: key),
            sourceType: _readString(item, 'source_type', parent: key),
            endpoint: _readString(item, 'endpoint', parent: key),
            lastSync: _readString(item, 'last_sync', parent: key),
            capabilities: _readStringValueList(
              item,
              'capabilities',
              parent: key,
            ),
            primaryAction: _readString(item, 'primary_action', parent: key),
          );
        })
        .toList(growable: false),
  );
}

List<SourceWizardStepContent> _readSourceWizardSteps(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<SourceWizardStepContent>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SourceWizardStepContent(
            step: _readSourceWizardStep(item, 'step', parent: key),
            title: _readString(item, 'title', parent: key),
            summary: _readString(item, 'summary', parent: key),
            primaryAction: _readString(item, 'primary_action', parent: key),
            secondaryAction: _readString(item, 'secondary_action', parent: key),
            fieldLabels: _readStringValueList(
              item,
              'field_labels',
              parent: key,
            ),
            helperLines: _readStringValueList(
              item,
              'helper_lines',
              parent: key,
            ),
          );
        })
        .toList(growable: false),
  );
}

ArtworkSource? _readArtworkSource(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$parent.$key must be an object when present');
  }
  final String kind = _readString(value, 'kind', parent: '$parent.$key');
  final String source = _readString(value, 'value', parent: '$parent.$key');
  return switch (kind) {
    'asset' => ArtworkSource.asset(source),
    'network' => ArtworkSource.network(source),
    _ =>
      throw FormatException(
        'unknown artwork source kind "$kind" in $parent.$key',
      ),
  };
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$parent.$key must be a non-empty string');
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be an integer when present');
}

List<String> _readStringValueList(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$parent.$key must be a non-empty array');
  }
  return List<String>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! String || item.isEmpty) {
            throw FormatException(
              '$parent.$key must contain only non-empty strings',
            );
          }
          return item;
        })
        .toList(growable: false),
  );
}

SourceWizardStep _readSourceWizardStep(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final String label = _readString(json, key, parent: parent);
  for (final SourceWizardStep step in SourceWizardStep.values) {
    if (step.label == label) {
      return step;
    }
  }
  throw FormatException('unknown source wizard step "$label" in $parent.$key');
}
