import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/providers/source_filter_provider.dart';
import 'package:crispy_tivi/core/widgets/source_selector_bar.dart';

// ── Minimal AppConfig for test SettingsState ─────────────────

const _testConfig = AppConfig(
  appName: 'Test',
  appVersion: '0.0.0',
  api: ApiConfig(
    baseUrl: 'http://localhost',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 10000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 5000,
    autoPlay: false,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#6750A4',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 360,
    channelListRefreshIntervalMinutes: 60,
    maxCachedEpgDays: 7,
  ),
);

// ── Stub notifiers ────────────────────────────────────────────

/// Synchronous stub for [SettingsNotifier] with a pre-built state.
class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._sources);

  final List<PlaylistSource> _sources;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _testConfig, sources: _sources);
}

// ── Helper sources ────────────────────────────────────────────

const _srcM3u = PlaylistSource(
  id: 'src-1',
  name: 'My IPTV',
  url: 'http://example.com/list.m3u',
  type: PlaylistSourceType.m3u,
);

const _srcXtream = PlaylistSource(
  id: 'src-2',
  name: 'Xtream Pro',
  url: 'http://xtream.example.com',
  type: PlaylistSourceType.xtream,
);

const _srcJellyfin = PlaylistSource(
  id: 'src-3',
  name: 'Jellyfin Home',
  url: 'http://jellyfin.local',
  type: PlaylistSourceType.jellyfin,
);

// ── Widget pump helper ────────────────────────────────────────

Widget _pumpBar({required List<PlaylistSource> sources}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StubSettingsNotifier(sources),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SizedBox(width: 800, child: SourceSelectorBar())),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────

void main() {
  group('SourceSelectorBar', () {
    testWidgets('renders nothing with 0 sources', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const []));
      await tester.pump();

      // With 0 sources, no ListView is rendered.
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders nothing with 1 source', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u]));
      await tester.pump();

      // With 1 source, no filtering UI is needed.
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders All + N chips with 2 sources', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcXtream]));
      await tester.pump();

      // "All Sources" + 2 source chips = 3 InkWell chips.
      expect(find.byType(InkWell), findsNWidgets(3));
      expect(find.text('All Sources'), findsOneWidget);
      expect(find.text('My IPTV'), findsOneWidget);
      expect(find.text('Xtream Pro'), findsOneWidget);
    });

    testWidgets('renders All + N chips with 3 sources', (tester) async {
      await tester.pumpWidget(
        _pumpBar(sources: const [_srcM3u, _srcXtream, _srcJellyfin]),
      );
      await tester.pump();

      // "All Sources" + 3 source chips = 4 InkWell chips.
      expect(find.byType(InkWell), findsNWidgets(4));
      expect(find.text('All Sources'), findsOneWidget);
      expect(find.text('Jellyfin Home'), findsOneWidget);
    });

    testWidgets('All Sources is selected by default', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcXtream]));
      await tester.pump();

      // "All Sources" chip is rendered.
      expect(find.text('All Sources'), findsOneWidget);

      // Provider state confirms no filter is active (= "All Sources" mode).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SourceSelectorBar)),
      );
      expect(container.read(sourceFilterProvider), isEmpty);
    });

    testWidgets('tapping a source chip toggles filter', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcXtream]));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SourceSelectorBar)),
      );
      // Initially no filter active.
      expect(container.read(sourceFilterProvider), isEmpty);

      // Tap 'My IPTV'.
      await tester.tap(find.text('My IPTV'));
      await tester.pump();

      expect(container.read(sourceFilterProvider), {'src-1'});
    });

    testWidgets('tapping a second source chip adds it to filter', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcXtream]));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SourceSelectorBar)),
      );

      await tester.tap(find.text('My IPTV'));
      await tester.pump();
      await tester.tap(find.text('Xtream Pro'));
      await tester.pump();

      expect(container.read(sourceFilterProvider), {'src-1', 'src-2'});
    });

    testWidgets('tapping All Sources clears the filter', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcXtream]));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SourceSelectorBar)),
      );

      // Select a source first via the notifier.
      container.read(sourceFilterProvider.notifier).toggle('src-1');
      await tester.pump();
      expect(container.read(sourceFilterProvider), isNotEmpty);

      // Tap 'All Sources'.
      await tester.tap(find.text('All Sources'));
      await tester.pump();

      expect(container.read(sourceFilterProvider), isEmpty);
    });

    testWidgets('tapping active chip again deselects it', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcXtream]));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SourceSelectorBar)),
      );

      // Select 'My IPTV'.
      await tester.tap(find.text('My IPTV'));
      await tester.pump();
      expect(container.read(sourceFilterProvider), {'src-1'});

      // Tap again to deselect.
      await tester.tap(find.text('My IPTV'));
      await tester.pump();
      expect(container.read(sourceFilterProvider), isEmpty);
    });

    testWidgets('shows type-specific icon for Jellyfin source', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcJellyfin]));
      await tester.pump();

      // Jellyfin type maps to Icons.dns_rounded.
      expect(find.byIcon(Icons.dns_rounded), findsOneWidget);
    });

    testWidgets('shows type-specific icon for Emby source', (tester) async {
      const srcEmby = PlaylistSource(
        id: 'src-emby',
        name: 'Emby Server',
        url: 'http://emby.local',
        type: PlaylistSourceType.emby,
      );
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, srcEmby]));
      await tester.pump();

      // Emby type maps to Icons.cast_connected_rounded.
      expect(find.byIcon(Icons.cast_connected_rounded), findsOneWidget);
    });

    testWidgets('shows type-specific icon for Plex source', (tester) async {
      const srcPlex = PlaylistSource(
        id: 'src-plex',
        name: 'Plex Media',
        url: 'http://plex.local',
        type: PlaylistSourceType.plex,
      );
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, srcPlex]));
      await tester.pump();

      // Plex type maps to Icons.play_circle_outline_rounded.
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('bar has 44px height when sources present', (tester) async {
      await tester.pumpWidget(_pumpBar(sources: const [_srcM3u, _srcXtream]));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(ListView),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.height, 44.0);
    });
  });
}
