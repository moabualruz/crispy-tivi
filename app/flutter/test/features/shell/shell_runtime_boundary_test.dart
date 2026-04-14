import 'package:crispy_tivi/app/app.dart';
import 'package:crispy_tivi/features/shell/data/asset_live_tv_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/data/live_tv_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asset repositories implement the retained runtime interfaces', () {
    expect(
      const AssetShellContractRepository(),
      isA<ShellContractRepository>(),
    );
    expect(const AssetShellContentRepository(), isA<ShellContentRepository>());
    expect(
      const AssetLiveTvRuntimeRepository(),
      isA<LiveTvRuntimeRepository>(),
    );
    expect(const AssetMediaRuntimeRepository(), isA<MediaRuntimeRepository>());
    expect(
      const AssetSearchRuntimeRepository(),
      isA<SearchRuntimeRepository>(),
    );
    expect(AssetShellBootstrapRepository(), isA<ShellBootstrapRepository>());
    expect(
      AssetPersonalizationRuntimeRepository(),
      isA<PersonalizationRuntimeRepository>(),
    );
  });

  testWidgets('app bootstraps from an injected runtime repository', (
    WidgetTester tester,
  ) async {
    final ShellContractSupport contract = ShellContractSupport.fromContract(
      ShellContract.fromJsonString('''
{
  "startup_route": "Home",
  "top_level_routes": ["Home", "Live TV", "Media", "Search", "Settings"],
  "settings_groups": ["General", "Playback", "Sources", "Appearance", "System"],
  "live_tv_panels": ["Channels", "Guide"],
  "live_tv_groups": ["All", "Favorites", "News", "Sports", "Movies", "Kids"],
  "media_panels": ["Movies", "Series"],
  "media_scopes": ["Featured", "Trending", "Recent", "Library"],
  "home_quick_access": ["Search", "Settings", "Series", "Live TV Guide"],
  "source_wizard_steps": ["Source Type", "Connection", "Credentials", "Import", "Finish"]
}
'''),
    );
    const ShellContentSnapshot content = ShellContentSnapshot(
      homeHero: HeroFeature(
        kicker: 'Tonight',
        title: 'Runtime injected',
        summary: 'Repository injection should bypass asset assumptions.',
        primaryAction: 'Resume',
        secondaryAction: 'Details',
      ),
      continueWatching: <ShelfItem>[],
      liveNow: <ShelfItem>[],
      movieHero: HeroFeature(
        kicker: 'Film',
        title: 'Runtime movie',
        summary: 'Injected content path.',
        primaryAction: 'Play trailer',
        secondaryAction: 'Watchlist',
      ),
      seriesHero: HeroFeature(
        kicker: 'Series',
        title: 'Runtime series',
        summary: 'Injected content path.',
        primaryAction: 'Resume',
        secondaryAction: 'Episodes',
      ),
      seriesDetail: SeriesDetailContent(
        summaryTitle: 'Runtime detail',
        summaryBody: 'Runtime injected series detail.',
        handoffLabel: 'Play episode',
        seasons: <SeriesSeasonDetail>[],
      ),
      topFilms: <ShelfItem>[],
      topSeries: <ShelfItem>[],
      liveTvChannels: <ChannelEntry>[],
      guideRows: <List<String>>[],
      liveTvBrowse: LiveTvBrowseContent(
        summaryTitle: 'Runtime browse',
        summaryBody: 'Runtime injected browse data.',
        quickPlayLabel: 'Play',
        quickPlayHint: 'Runtime path',
        selectedChannelNumber: '101',
        channelDetails: <LiveTvChannelDetail>[],
      ),
      liveTvGuide: LiveTvGuideContent(
        summaryTitle: 'Runtime guide',
        summaryBody: 'Runtime injected guide data.',
        timeSlots: <String>[],
        selectedChannelNumber: '101',
        focusedSlot: 'Now',
        rows: <LiveTvGuideRowDetail>[],
      ),
      searchGroups: <SearchResultGroup>[],
      generalSettings: <SettingsItem>[],
      playbackSettings: <SettingsItem>[],
      appearanceSettings: <SettingsItem>[],
      systemSettings: <SettingsItem>[],
      sourceHealthItems: <SourceHealthItem>[],
      sourceWizardSteps: <SourceWizardStepContent>[],
    );

    await tester.pumpWidget(
      CrispyTiviApp(
        bootstrapRepository: _RuntimeBootstrapRepository(
          contract: contract,
          content: content,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Provider catalog unavailable'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _RuntimeBootstrapRepository extends ShellBootstrapRepository {
  const _RuntimeBootstrapRepository({
    required this.contract,
    required this.content,
  });

  final ShellContractSupport contract;
  final ShellContentSnapshot content;

  @override
  Future<ShellBootstrap> load() async {
    return ShellBootstrap(
      contract: contract,
      content: content,
      mediaRuntime: MediaRuntimeSnapshot(
        title: 'Injected media runtime',
        version: '1',
        activePanel: 'Movies',
        activeScope: 'Featured',
        movieHero: MediaRuntimeHeroSnapshot(
          kicker: content.homeHero.kicker,
          title: content.homeHero.title,
          summary: content.homeHero.summary,
          primaryAction: content.homeHero.primaryAction,
          secondaryAction: content.homeHero.secondaryAction,
          artwork: content.homeHero.artwork,
        ),
        seriesHero: const MediaRuntimeHeroSnapshot.empty(),
        movieCollections: const <MediaRuntimeCollectionSnapshot>[],
        seriesCollections: const <MediaRuntimeCollectionSnapshot>[],
        seriesDetail: const MediaRuntimeSeriesDetailSnapshot.empty(),
        notes: const <String>['Injected runtime repository.'],
      ),
    );
  }
}
