import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/player/data/player_service.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/player_osd.dart';

class MockPlayerService extends Mock implements PlayerService {}

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

class _EmptyBufferRangesNotifier extends BufferRangesNotifier {
  @override
  List<(double, double)> build() => const [];
}

/// Forces OSD to always be visible so the golden
/// captures the overlay rather than blank screen.
class _AlwaysVisibleOsdNotifier extends OsdStateNotifier {
  @override
  OsdState build() => OsdState.visible;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'PlayerOsd golden — live mode 1280x720 LIVE badge and channel info',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MemoryBackend();
      final cache = CacheService(backend);

      final mockPlayerService = MockPlayerService();
      final mockPlayer = MockCrispyPlayer();

      when(() => mockPlayerService.player).thenReturn(mockPlayer);
      when(
        () => mockPlayerService.state,
      ).thenReturn(const PlaybackState(isLive: true, channelName: 'BBC News'));
      when(
        () => mockPlayerService.streamInfo,
      ).thenReturn({'Resolution': '1920x1080', 'Bitrate': '8000 kbps'});
      when(() => mockPlayerService.playOrPause()).thenAnswer((_) async {});
      when(() => mockPlayerService.refresh()).thenAnswer((_) async {});
      when(() => mockPlayerService.cycleAspectRatio()).thenAnswer((_) async {});
      when(() => mockPlayerService.setVolume(any())).thenAnswer((_) async {});
      when(() => mockPlayerService.toggleMute()).thenReturn(null);
      when(() => mockPlayerService.seek(any())).thenAnswer((_) async {});
      when(() => mockPlayer.audioTracks).thenReturn(const []);
      when(() => mockPlayer.subtitleTracks).thenReturn(const []);
      when(() => mockPlayer.isPlaying).thenReturn(false);

      const liveState = PlaybackState(
        isLive: true,
        channelName: 'BBC News',
        channelLogoUrl: null,
        volume: 1.0,
        duration: Duration.zero,
        status: PlaybackStatus.playing,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crispyBackendProvider.overrideWithValue(backend),
            cacheServiceProvider.overrideWithValue(cache),
            playerServiceProvider.overrideWithValue(mockPlayerService),
            playerProvider.overrideWithValue(mockPlayer),
            playbackStateProvider.overrideWith(
              (ref) => Stream.value(liveState),
            ),
            osdStateProvider.overrideWith(() => _AlwaysVisibleOsdNotifier()),
            streamStatsVisibleProvider.overrideWith(
              () => StreamStatsNotifier(),
            ),
            bufferRangesProvider.overrideWith(
              () => _EmptyBufferRangesNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.fromThemeState(const ThemeState()).theme,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1280, 720)),
              child: const Scaffold(
                backgroundColor: Colors.black,
                body: PlayerOsd(state: liveState),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PlayerOsd),
        matchesGoldenFile('goldens/player_osd_live.png'),
      );
    },
  );

  testWidgets(
    'PlayerOsd golden — VOD mode 1280x720 with seek bar and time display',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MemoryBackend();
      final cache = CacheService(backend);

      final mockPlayerService = MockPlayerService();
      final mockPlayer = MockCrispyPlayer();

      when(() => mockPlayerService.player).thenReturn(mockPlayer);
      when(() => mockPlayerService.state).thenReturn(
        const PlaybackState(
          isLive: false,
          channelName: 'Inception (2010)',
          duration: Duration(minutes: 148),
          position: Duration(minutes: 42),
        ),
      );
      when(
        () => mockPlayerService.streamInfo,
      ).thenReturn({'Resolution': '1920x1080', 'Bitrate': '6000 kbps'});
      when(() => mockPlayerService.playOrPause()).thenAnswer((_) async {});
      when(() => mockPlayerService.refresh()).thenAnswer((_) async {});
      when(() => mockPlayerService.cycleAspectRatio()).thenAnswer((_) async {});
      when(() => mockPlayerService.setVolume(any())).thenAnswer((_) async {});
      when(() => mockPlayerService.toggleMute()).thenReturn(null);
      when(() => mockPlayerService.seek(any())).thenAnswer((_) async {});
      when(() => mockPlayer.audioTracks).thenReturn(const []);
      when(() => mockPlayer.subtitleTracks).thenReturn(const []);
      when(() => mockPlayer.isPlaying).thenReturn(true);

      const vodState = PlaybackState(
        isLive: false,
        channelName: 'Inception (2010)',
        channelLogoUrl: null,
        volume: 1.0,
        duration: Duration(minutes: 148),
        position: Duration(minutes: 42),
        status: PlaybackStatus.playing,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crispyBackendProvider.overrideWithValue(backend),
            cacheServiceProvider.overrideWithValue(cache),
            playerServiceProvider.overrideWithValue(mockPlayerService),
            playerProvider.overrideWithValue(mockPlayer),
            playbackStateProvider.overrideWith((ref) => Stream.value(vodState)),
            osdStateProvider.overrideWith(() => _AlwaysVisibleOsdNotifier()),
            streamStatsVisibleProvider.overrideWith(
              () => StreamStatsNotifier(),
            ),
            bufferRangesProvider.overrideWith(
              () => _EmptyBufferRangesNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.fromThemeState(const ThemeState()).theme,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1280, 720)),
              child: const Scaffold(
                backgroundColor: Colors.black,
                body: PlayerOsd(state: vodState),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PlayerOsd),
        matchesGoldenFile('goldens/player_osd_vod.png'),
      );
    },
  );
}
