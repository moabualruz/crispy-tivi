import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/player_view.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/player_playback_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('movie player shows transport controls and chooser overlay', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerView(
            session: _movieSession(),
            playbackController: PlayerPlaybackController(),
            chromeState: PlayerChromeState.transport,
            activeChooser: PlayerChooserKind.subtitles,
            onBack: () {},
            onOpenInfo: () {},
            onOpenChooser: (_) {},
            onSelectChooserOption: (_, optionIndex) {},
            onSelectQueueIndex: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('player-back-action')), findsOneWidget);
    expect(find.byKey(const Key('player-open-info')), findsOneWidget);
    expect(find.byKey(const Key('player-progress-bar')), findsOneWidget);
    expect(find.byKey(const Key('player-chooser-subtitles')), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('English CC'), findsOneWidget);
    expect(find.text('The Last Harbor'), findsOneWidget);
  });

  testWidgets('live player shows live badge and expanded queue state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerView(
            session: _liveSession(),
            playbackController: PlayerPlaybackController(),
            chromeState: PlayerChromeState.expandedInfo,
            activeChooser: null,
            onBack: () {},
            onOpenInfo: () {},
            onOpenChooser: (_) {},
            onSelectChooserOption: (_, optionIndex) {},
            onSelectQueueIndex: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Channels'), findsOneWidget);
    expect(find.byKey(const Key('player-queue-item-0')), findsOneWidget);
    expect(find.byKey(const Key('player-queue-item-1')), findsOneWidget);
    expect(find.text('Championship Replay'), findsWidgets);
    expect(find.text('Now playing'), findsOneWidget);
  });

  testWidgets('player uses playback backend surface when a uri exists', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final String playbackUri = 'https://example.com/sample.m3u8';
    bool built = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerView(
            session: _movieSession(playbackUri: playbackUri),
            playbackController: PlayerPlaybackController(),
            chromeState: PlayerChromeState.transport,
            activeChooser: null,
            onBack: () {},
            onOpenInfo: () {},
            onOpenChooser: (_) {},
            onSelectChooserOption: (_, optionIndex) {},
            onSelectQueueIndex: (_) {},
            playbackSurfaceBuilder: (String uri) {
              built = uri == playbackUri;
              return const SizedBox(key: Key('player-backend-surface'));
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(built, isTrue);
    expect(find.byKey(const Key('player-backend-surface')), findsOneWidget);
  });
}

PlayerSession _movieSession({String? playbackUri}) {
  return PlayerSession(
    kind: PlayerContentKind.movie,
    originLabel: 'Media · Movies',
    queueLabel: 'Up next',
    queue: <PlayerQueueItem>[
      PlayerQueueItem(
        eyebrow: 'Featured film',
        title: 'The Last Harbor',
        subtitle: 'Thriller · 2026 · Dolby Audio',
        summary: 'Resume directly into the film.',
        progressLabel: '01:24 / 02:11 · Resume from your last position',
        progressValue: 0.64,
        badges: <String>['4K', 'Dolby Audio', 'Resume'],
        detailLines: <String>[
          'The Last Harbor',
          'Feature playback keeps shell chrome out of the way.',
        ],
      ),
    ],
    activeIndex: 0,
    primaryActionLabel: 'Resume',
    secondaryActionLabel: 'Restart',
    chooserGroups: <PlayerChooserGroup>[
      PlayerChooserGroup(
        kind: PlayerChooserKind.audio,
        title: 'Audio',
        options: _options('English 5.1', 'English Stereo'),
        selectedIndex: 0,
      ),
      PlayerChooserGroup(
        kind: PlayerChooserKind.subtitles,
        title: 'Subtitles',
        options: _options('Off', 'English CC'),
        selectedIndex: 1,
      ),
      PlayerChooserGroup(
        kind: PlayerChooserKind.quality,
        title: 'Quality',
        options: _options('Auto', '4K HDR'),
        selectedIndex: 0,
      ),
      PlayerChooserGroup(
        kind: PlayerChooserKind.source,
        title: 'Source',
        options: _options('Preferred source', 'Mirror source'),
        selectedIndex: 0,
      ),
    ],
    statsLines: <String>['Playback path: internal player'],
  ).copyWith(playbackUri: playbackUri);
}

PlayerSession _liveSession({String? playbackUri}) {
  return PlayerSession(
    kind: PlayerContentKind.live,
    originLabel: 'Live TV · Sports',
    queueLabel: 'Channels',
    queue: <PlayerQueueItem>[
      PlayerQueueItem(
        eyebrow: 'Live TV · 118',
        title: 'Championship Replay',
        subtitle: 'Arena Live · 21:30–23:30',
        summary: 'Live playback stays anchored by a LIVE state badge.',
        progressLabel: 'Now · Championship Replay · Live edge',
        progressValue: 0.96,
        badges: <String>['Sports', '4K', 'Catch-up'],
        detailLines: <String>[
          'Focused guide slot: 22:00',
          'Switch path: next/previous channel',
        ],
      ),
      PlayerQueueItem(
        eyebrow: 'Live TV · 205',
        title: 'Coastal Drive',
        subtitle: 'Cinema Vault · 20:45–22:35',
        summary: 'Movie lane with archive support.',
        progressLabel: 'Now · Coastal Drive · Live edge',
        progressValue: 0.72,
        badges: <String>['Movies', 'Dolby', 'Archive'],
        detailLines: <String>[
          'Focused guide slot: 22:00',
          'Switch path: next/previous channel',
        ],
      ),
    ],
    activeIndex: 0,
    primaryActionLabel: 'Go Live',
    secondaryActionLabel: 'Restart',
    chooserGroups: <PlayerChooserGroup>[
      PlayerChooserGroup(
        kind: PlayerChooserKind.audio,
        title: 'Audio',
        options: _options('Stadium mix', 'Commentary'),
        selectedIndex: 0,
      ),
      PlayerChooserGroup(
        kind: PlayerChooserKind.subtitles,
        title: 'Subtitles',
        options: _options('Off', 'English CC'),
        selectedIndex: 0,
      ),
      PlayerChooserGroup(
        kind: PlayerChooserKind.quality,
        title: 'Quality',
        options: _options('Auto', '4K'),
        selectedIndex: 0,
      ),
      PlayerChooserGroup(
        kind: PlayerChooserKind.source,
        title: 'Source',
        options: _options('Primary source', 'Mirror source'),
        selectedIndex: 0,
      ),
    ],
    statsLines: <String>['Live edge: active', 'Archive: available'],
  ).copyWith(playbackUri: playbackUri);
}

List<PlayerChooserOption> _options(String first, [String? second]) {
  final List<String> labels = <String>[first, if (second != null) second];
  return labels
      .map(
        (String label) => PlayerChooserOption(
          id: label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
          label: label,
        ),
      )
      .toList(growable: false);
}
