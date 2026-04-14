import 'dart:convert';

import 'package:crispy_tivi/features/shell/data/playback_session_runtime.dart';
import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/media/media_presentation_adapter.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/live_tv_view.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/media_view.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/search_view.dart';
import 'package:crispy_tivi/features/shell/presentation/search/search_presentation_adapter.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/player_playback_controller.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_rust_api.dart';

void main() {
  setUpAll(() async {
    await RustShellRuntimeBridge.initializeMock(api: const TestRustApi());
  });

  testWidgets('movie launch sessions carry a runtime playback target', (
    WidgetTester tester,
  ) async {
    final String source = await rootBundle.loadString(
      'assets/contracts/asset_media_runtime.json',
    );
    final MediaRuntimeSnapshot runtime = MediaRuntimeSnapshot.fromJsonString(
      source,
    );
    final state = MediaPresentationAdapter.build(
      runtime: runtime,
      personalization: const PersonalizationRuntimeSnapshot.empty(),
      availableScopes: MediaScope.values,
      panel: MediaPanel.movies,
      scope: MediaScope.featured,
      seriesSeasonIndex: 0,
      seriesEpisodeIndex: 0,
      launchedSeriesEpisodeIndex: 0,
    );

    PlayerSession? launchedSession;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaView(
            runtime: runtime,
            state: state,
            onSelectScope: (_) {},
            onSelectSeriesSeasonIndex: (_) {},
            onSelectSeriesEpisodeIndex: (_) {},
            onLaunchSeriesEpisode: () {},
            onLaunchPlayer:
                (PlayerSession session) => launchedSession = session,
            onToggleWatchlist: (_) {},
            watchlistContentKeys: const <String>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('movie-detail-card')),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-player-launch')));
    await tester.pumpAndSettle();

    expect(launchedSession, isNotNull);
    expect(
      launchedSession!.playbackUri,
      'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
    );
    expect(
      launchedSession!.activeItem.playbackStream?.uri,
      'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
    );
    expect(launchedSession!.activeItem.playbackSource?.kind, 'movie');
  });

  testWidgets('live launch sessions carry a runtime playback target', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final LiveTvRuntimeSnapshot runtime = LiveTvRuntimeSnapshot.fromJsonString(
      await rootBundle.loadString(
        'assets/contracts/asset_live_tv_runtime.json',
      ),
    );
    PlayerSession? launchedSession;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveTvView(
            runtime: runtime,
            panel: LiveTvPanel.channels,
            groupId: 'all',
            focusedChannelIndex: 0,
            playingChannelIndex: 0,
            onSelectGroup: (_) {},
            onSelectChannel: (_) {},
            onActivateChannel: () {},
            onLaunchPlayer:
                (PlayerSession session) => launchedSession = session,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder tuneAction =
        find.byKey(const Key('live-tv-tune-action')).first;
    await tester.ensureVisible(tuneAction);
    await tester.tap(tuneAction);
    await tester.pumpAndSettle();

    expect(launchedSession, isNotNull);
    expect(
      launchedSession!.playbackUri,
      'https://stream.crispy-tivi.test/live/101.m3u8',
    );
    expect(
      launchedSession!.activeItem.playbackStream?.uri,
      'https://stream.crispy-tivi.test/live/101.m3u8',
    );
    expect(launchedSession!.activeItem.playbackSource?.kind, 'live_channel');
    expect(runtime.provider.providerType, 'M3U + XMLTV');
    expect(runtime.channels.first.catchUp, isTrue);
    expect(runtime.channels.first.archive, isTrue);
  });

  testWidgets('search presentation still resolves its retained groups', (
    WidgetTester tester,
  ) async {
    final SearchRuntimeSnapshot runtime = SearchRuntimeSnapshot.fromJsonString(
      await rootBundle.loadString('assets/contracts/asset_search_runtime.json'),
    );
    final state = SearchPresentationAdapter.build(runtime: runtime);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SearchView(state: state))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live TV'), findsWidgets);
    expect(find.text('Arena Live'), findsWidgets);
  });

  test('playback runtime bridge returns source and track options', () async {
    final String json =
        await const RustShellRuntimeBridge().loadPlaybackRuntimeJson();
    final PlaybackStreamSnapshot snapshot = PlaybackStreamSnapshot.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
      parent: 'playback_runtime',
    );

    expect(snapshot.sourceOptions, isNotEmpty);
    expect(snapshot.qualityOptions, isNotEmpty);
    expect(snapshot.audioOptions, isNotEmpty);
    expect(snapshot.subtitleOptions, isNotEmpty);
  });

  test('playback controller keeps non-http runtime uris from Rust', () async {
    final PlayerPlaybackController controller = PlayerPlaybackController();
    addTearDown(controller.dispose);

    await controller.syncSession(
      PlayerSession(
        kind: PlayerContentKind.movie,
        originLabel: 'Media · Movies',
        queueLabel: 'Up next',
        queue: <PlayerQueueItem>[
          const PlayerQueueItem(
            eyebrow: 'Featured film',
            title: 'The Last Harbor',
            subtitle: 'Thriller · 2026',
            summary: 'Runtime-backed playback target.',
            progressLabel: '00:00 / 02:11',
            progressValue: 0.0,
            badges: <String>['Runtime'],
            detailLines: <String>['Rust owns the playback snapshot.'],
          ),
        ],
        activeIndex: 0,
        primaryActionLabel: 'Resume',
        secondaryActionLabel: 'Restart',
        chooserGroups: const <PlayerChooserGroup>[],
        statsLines: const <String>[],
        playbackUri: 'data:text/plain;base64,SGVsbG8=',
      ),
    );

    expect(controller.loadedUri, 'data:text/plain;base64,SGVsbG8=');
    expect(controller.backendReady, isTrue);
  });

  test(
    'playback controller consumes the repository seam for playback uris',
    () async {
      final PlayerPlaybackController controller = PlayerPlaybackController(
        playbackSessionRuntimeRepository:
            _FakePlaybackSessionRuntimeRepository(),
      );
      addTearDown(controller.dispose);

      await controller.syncSession(
        PlayerSession(
          kind: PlayerContentKind.movie,
          originLabel: 'Media · Movies',
          queueLabel: 'Up next',
          queue: <PlayerQueueItem>[
            const PlayerQueueItem(
              eyebrow: 'Featured film',
              title: 'Repository seam',
              subtitle: 'Playback target',
              summary: 'Controller stays out of derivation.',
              progressLabel: '00:00 / 00:00',
              progressValue: 0,
              badges: <String>[],
              detailLines: <String>[],
            ),
          ],
          activeIndex: 0,
          primaryActionLabel: 'Resume',
          secondaryActionLabel: 'Restart',
          chooserGroups: const <PlayerChooserGroup>[],
          statsLines: const <String>[],
        ),
      );

      expect(controller.loadedUri, 'data:text/plain;base64,repo-seam');
      expect(controller.backendReady, isTrue);
    },
  );
}

final class _FakePlaybackSessionRuntimeRepository
    extends PlaybackSessionRuntimeRepository {
  @override
  List<PlayerChooserGroup> chooserGroupsForQueueItem(PlayerQueueItem item) {
    return const <PlayerChooserGroup>[];
  }

  @override
  PlayerSession hydratePlayerSession(PlayerSession session) {
    return session;
  }

  @override
  PlayerSession selectPlayerSessionChooserOption(
    PlayerSession session,
    PlayerChooserKind kind,
    int optionIndex,
  ) {
    return session;
  }

  @override
  PlayerSession selectPlayerSessionQueueIndex(
    PlayerSession session,
    int index,
  ) {
    return session;
  }

  @override
  String? resolvedPlaybackUriForSession(PlayerSession session) {
    return 'data:text/plain;base64,repo-seam';
  }

  @override
  PlaybackTrackOptionSnapshot? selectedTrackOptionForSession(
    PlayerSession session,
    PlayerChooserKind kind,
  ) {
    return null;
  }

  @override
  PlaybackVariantOptionSnapshot? selectedVariantOptionForSession(
    PlayerSession session,
    PlayerChooserKind kind,
  ) {
    return null;
  }
}
