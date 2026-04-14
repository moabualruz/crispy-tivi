import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';

class ShellContentSnapshot {
  const ShellContentSnapshot({
    required this.homeHero,
    required this.continueWatching,
    required this.liveNow,
    required this.movieHero,
    required this.seriesHero,
    required this.seriesDetail,
    required this.topFilms,
    required this.topSeries,
    required this.liveTvChannels,
    required this.guideRows,
    required this.liveTvBrowse,
    required this.liveTvGuide,
    required this.searchGroups,
    required this.generalSettings,
    required this.playbackSettings,
    required this.appearanceSettings,
    required this.systemSettings,
    required this.sourceHealthItems,
    required this.sourceWizardSteps,
  });

  const ShellContentSnapshot.empty()
    : homeHero = HeroFeature.empty,
      continueWatching = const <ShelfItem>[],
      liveNow = const <ShelfItem>[],
      movieHero = HeroFeature.empty,
      seriesHero = HeroFeature.empty,
      seriesDetail = SeriesDetailContent.empty,
      topFilms = const <ShelfItem>[],
      topSeries = const <ShelfItem>[],
      liveTvChannels = const <ChannelEntry>[],
      guideRows = const <List<String>>[],
      liveTvBrowse = const LiveTvBrowseContent(
        summaryTitle: '',
        summaryBody: '',
        quickPlayLabel: '',
        quickPlayHint: '',
        selectedChannelNumber: '',
        channelDetails: <LiveTvChannelDetail>[],
      ),
      liveTvGuide = const LiveTvGuideContent(
        summaryTitle: '',
        summaryBody: '',
        timeSlots: <String>[],
        selectedChannelNumber: '',
        focusedSlot: '',
        rows: <LiveTvGuideRowDetail>[],
      ),
      searchGroups = const <SearchResultGroup>[],
      generalSettings = const <SettingsItem>[],
      playbackSettings = const <SettingsItem>[],
      appearanceSettings = const <SettingsItem>[],
      systemSettings = const <SettingsItem>[],
      sourceHealthItems = const <SourceHealthItem>[],
      sourceWizardSteps = const <SourceWizardStepContent>[];

  factory ShellContentSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('shell content must be a JSON object');
    }
    return ShellContentSnapshot.fromJson(decoded);
  }

  factory ShellContentSnapshot.fromJson(Map<String, dynamic> json) {
    return ShellContentSnapshot(
      homeHero: _readHeroFeature(json, 'home_hero'),
      continueWatching: _readShelfItems(json, 'continue_watching'),
      liveNow: _readShelfItems(json, 'live_now'),
      movieHero: _readHeroFeature(json, 'movie_hero'),
      seriesHero: _readHeroFeature(json, 'series_hero'),
      seriesDetail: _readSeriesDetailContent(
        json,
        'series_detail',
        fallbackHero: _readHeroFeature(json, 'series_hero'),
        fallbackShelf: _readShelfItems(json, 'top_series'),
      ),
      topFilms: _readShelfItems(json, 'top_films'),
      topSeries: _readShelfItems(json, 'top_series'),
      liveTvChannels: _readChannelEntries(json, 'live_tv_channels'),
      guideRows: _readGuideRows(json, 'guide_rows'),
      liveTvBrowse: _readLiveTvBrowseContent(json, 'live_tv_browse'),
      liveTvGuide: _readLiveTvGuideContent(json, 'live_tv_guide'),
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
  final SeriesDetailContent seriesDetail;
  final List<ShelfItem> topFilms;
  final List<ShelfItem> topSeries;
  final List<ChannelEntry> liveTvChannels;
  final List<List<String>> guideRows;
  final LiveTvBrowseContent liveTvBrowse;
  final LiveTvGuideContent liveTvGuide;
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

SeriesDetailContent _readSeriesDetailContent(
  Map<String, dynamic> json,
  String key, {
  required HeroFeature fallbackHero,
  required List<ShelfItem> fallbackShelf,
}) {
  final Object? value = json[key];
  if (value == null) {
    return _fallbackSeriesDetailContent(
      fallbackHero: fallbackHero,
      fallbackShelf: fallbackShelf,
    );
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  return SeriesDetailContent(
    summaryTitle: _readString(value, 'summary_title', parent: key),
    summaryBody: _readString(value, 'summary_body', parent: key),
    handoffLabel: _readString(value, 'handoff_label', parent: key),
    seasons: _readSeriesSeasons(value, 'seasons'),
  );
}

List<SeriesSeasonDetail> _readSeriesSeasons(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<SeriesSeasonDetail>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SeriesSeasonDetail(
            label: _readString(item, 'label', parent: key),
            summary: _readString(item, 'summary', parent: key),
            episodes: _readSeriesEpisodes(item, 'episodes'),
          );
        })
        .toList(growable: false),
  );
}

List<SeriesEpisodeDetail> _readSeriesEpisodes(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<SeriesEpisodeDetail>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SeriesEpisodeDetail(
            code: _readString(item, 'code', parent: key),
            title: _readString(item, 'title', parent: key),
            summary: _readString(item, 'summary', parent: key),
            durationLabel: _readString(item, 'duration_label', parent: key),
            handoffLabel: _readString(item, 'handoff_label', parent: key),
          );
        })
        .toList(growable: false),
  );
}

SeriesDetailContent _fallbackSeriesDetailContent({
  required HeroFeature fallbackHero,
  required List<ShelfItem> fallbackShelf,
}) {
  final String heroTitle = fallbackHero.title;
  final List<SeriesEpisodeDetail>
  episodeSet = List<SeriesEpisodeDetail>.unmodifiable(<SeriesEpisodeDetail>[
    SeriesEpisodeDetail(
      code: 'S1:E1',
      title: fallbackShelf.isNotEmpty ? fallbackShelf.first.title : heroTitle,
      summary:
          fallbackShelf.isNotEmpty
              ? fallbackShelf.first.caption
              : '$heroTitle opens directly in the series surface.',
      durationLabel: '45 min',
      handoffLabel: 'Play episode',
    ),
    SeriesEpisodeDetail(
      code: 'S1:E2',
      title:
          fallbackShelf.length > 1
              ? fallbackShelf[1].title
              : '$heroTitle follow-up',
      summary:
          fallbackShelf.length > 1
              ? fallbackShelf[1].caption
              : 'Continue the season flow from the previous episode.',
      durationLabel: '42 min',
      handoffLabel: 'Play episode',
    ),
    SeriesEpisodeDetail(
      code: 'S1:E3',
      title: '$heroTitle bridge',
      summary:
          'Carry the story into the next chapter without leaving the series surface.',
      durationLabel: '47 min',
      handoffLabel: 'Play episode',
    ),
  ]);
  return SeriesDetailContent(
    summaryTitle: 'Season and episode playback',
    summaryBody:
        '$heroTitle keeps season choice above episode choice and keeps playback inside the player.',
    handoffLabel: 'Play episode',
    seasons: List<SeriesSeasonDetail>.unmodifiable(<SeriesSeasonDetail>[
      SeriesSeasonDetail(
        label: 'Season 1',
        summary: 'Entry season for the current series surface.',
        episodes: episodeSet,
      ),
      SeriesSeasonDetail(
        label: 'Season 2',
        summary:
            'Continuation season with playback ready for the next episode.',
        episodes: List<SeriesEpisodeDetail>.unmodifiable(
          episodeSet
              .map(
                (SeriesEpisodeDetail episode) => SeriesEpisodeDetail(
                  code: episode.code.replaceFirst('S1', 'S2'),
                  title: episode.title,
                  summary: episode.summary,
                  durationLabel: episode.durationLabel,
                  handoffLabel: episode.handoffLabel,
                ),
              )
              .toList(growable: false),
        ),
      ),
    ]),
  );
}

final class LiveTvBrowseContent {
  const LiveTvBrowseContent({
    required this.summaryTitle,
    required this.summaryBody,
    required this.quickPlayLabel,
    required this.quickPlayHint,
    required this.selectedChannelNumber,
    required this.channelDetails,
  });

  final String summaryTitle;
  final String summaryBody;
  final String quickPlayLabel;
  final String quickPlayHint;
  final String selectedChannelNumber;
  final List<LiveTvChannelDetail> channelDetails;
}

final class LiveTvChannelDetail {
  const LiveTvChannelDetail({
    required this.number,
    required this.brand,
    required this.title,
    required this.summary,
    required this.nowLabel,
    required this.nextLabel,
    required this.quickPlayLabel,
    required this.metadataBadges,
    required this.supportsCatchup,
    required this.supportsArchive,
    required this.archiveHint,
  });

  final String number;
  final String brand;
  final String title;
  final String summary;
  final String nowLabel;
  final String nextLabel;
  final String quickPlayLabel;
  final List<String> metadataBadges;
  final bool supportsCatchup;
  final bool supportsArchive;
  final String archiveHint;
}

final class LiveTvGuideContent {
  const LiveTvGuideContent({
    required this.summaryTitle,
    required this.summaryBody,
    required this.timeSlots,
    required this.selectedChannelNumber,
    required this.focusedSlot,
    required this.rows,
  });

  final String summaryTitle;
  final String summaryBody;
  final List<String> timeSlots;
  final String selectedChannelNumber;
  final String focusedSlot;
  final List<LiveTvGuideRowDetail> rows;
}

final class LiveTvGuideRowDetail {
  const LiveTvGuideRowDetail({
    required this.channelNumber,
    required this.channelName,
    required this.programs,
  });

  final String channelNumber;
  final String channelName;
  final List<LiveTvProgramDetail> programs;
}

final class LiveTvProgramDetail {
  const LiveTvProgramDetail({
    required this.slot,
    required this.title,
    required this.summary,
    required this.durationLabel,
    required this.supportsCatchup,
    required this.supportsArchive,
    required this.liveEdgeLabel,
  });

  final String slot;
  final String title;
  final String summary;
  final String durationLabel;
  final bool supportsCatchup;
  final bool supportsArchive;
  final String liveEdgeLabel;
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

LiveTvBrowseContent _readLiveTvBrowseContent(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  final Object? channelDetails = value['channel_details'];
  if (channelDetails is! List<Object?> || channelDetails.isEmpty) {
    throw FormatException('$key.channel_details must be a non-empty array');
  }
  return LiveTvBrowseContent(
    summaryTitle: _readString(value, 'summary_title', parent: key),
    summaryBody: _readString(value, 'summary_body', parent: key),
    quickPlayLabel: _readString(value, 'quick_play_label', parent: key),
    quickPlayHint: _readString(value, 'quick_play_hint', parent: key),
    selectedChannelNumber: _readString(
      value,
      'selected_channel_number',
      parent: key,
    ),
    channelDetails: List<LiveTvChannelDetail>.unmodifiable(
      channelDetails
          .map((Object? item) {
            if (item is! Map<String, dynamic>) {
              throw FormatException(
                '$key.channel_details must contain only objects',
              );
            }
            return LiveTvChannelDetail(
              number: _readString(
                item,
                'number',
                parent: '$key.channel_details',
              ),
              brand: _readString(item, 'brand', parent: '$key.channel_details'),
              title: _readString(item, 'title', parent: '$key.channel_details'),
              summary: _readString(
                item,
                'summary',
                parent: '$key.channel_details',
              ),
              nowLabel: _readString(
                item,
                'now_label',
                parent: '$key.channel_details',
              ),
              nextLabel: _readString(
                item,
                'next_label',
                parent: '$key.channel_details',
              ),
              quickPlayLabel: _readString(
                item,
                'quick_play_label',
                parent: '$key.channel_details',
              ),
              metadataBadges: _readStringValueList(
                item,
                'metadata_badges',
                parent: '$key.channel_details',
              ),
              supportsCatchup: _readRequiredBool(
                item,
                'supports_catchup',
                parent: '$key.channel_details',
              ),
              supportsArchive: _readRequiredBool(
                item,
                'supports_archive',
                parent: '$key.channel_details',
              ),
              archiveHint: _readString(
                item,
                'archive_hint',
                parent: '$key.channel_details',
              ),
            );
          })
          .toList(growable: false),
    ),
  );
}

LiveTvGuideContent _readLiveTvGuideContent(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  final Object? rows = value['rows'];
  if (rows is! List<Object?> || rows.isEmpty) {
    throw FormatException('$key.rows must be a non-empty array');
  }
  return LiveTvGuideContent(
    summaryTitle: _readString(value, 'summary_title', parent: key),
    summaryBody: _readString(value, 'summary_body', parent: key),
    timeSlots: _readStringValueList(value, 'time_slots', parent: key),
    selectedChannelNumber: _readString(
      value,
      'selected_channel_number',
      parent: key,
    ),
    focusedSlot: _readString(value, 'focused_slot', parent: key),
    rows: List<LiveTvGuideRowDetail>.unmodifiable(
      rows
          .map((Object? item) {
            if (item is! Map<String, dynamic>) {
              throw FormatException('$key.rows must contain only objects');
            }
            final Object? programs = item['programs'];
            if (programs is! List<Object?> || programs.isEmpty) {
              throw FormatException(
                '$key.rows.programs must be a non-empty array',
              );
            }
            return LiveTvGuideRowDetail(
              channelNumber: _readString(
                item,
                'channel_number',
                parent: '$key.rows',
              ),
              channelName: _readString(
                item,
                'channel_name',
                parent: '$key.rows',
              ),
              programs: List<LiveTvProgramDetail>.unmodifiable(
                programs
                    .map((Object? program) {
                      if (program is! Map<String, dynamic>) {
                        throw FormatException(
                          '$key.rows.programs must contain only objects',
                        );
                      }
                      return LiveTvProgramDetail(
                        slot: _readString(
                          program,
                          'slot',
                          parent: '$key.rows.programs',
                        ),
                        title: _readString(
                          program,
                          'title',
                          parent: '$key.rows.programs',
                        ),
                        summary: _readString(
                          program,
                          'summary',
                          parent: '$key.rows.programs',
                        ),
                        durationLabel: _readString(
                          program,
                          'duration_label',
                          parent: '$key.rows.programs',
                        ),
                        supportsCatchup: _readRequiredBool(
                          program,
                          'supports_catchup',
                          parent: '$key.rows.programs',
                        ),
                        supportsArchive: _readRequiredBool(
                          program,
                          'supports_archive',
                          parent: '$key.rows.programs',
                        ),
                        liveEdgeLabel: _readString(
                          program,
                          'live_edge_label',
                          parent: '$key.rows.programs',
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            );
          })
          .toList(growable: false),
    ),
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

bool _readRequiredBool(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$parent.$key must be a boolean');
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
