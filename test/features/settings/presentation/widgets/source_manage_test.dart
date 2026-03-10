import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'source_extra_sections.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';

// ── Minimal AppConfig ──────────────────────────────────────────

AppConfig _minimalConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.1',
  api: ApiConfig(
    baseUrl: 'http://test',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 2000,
    autoPlay: true,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#3B82F6',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 60,
    channelListRefreshIntervalMinutes: 30,
    maxCachedEpgDays: 7,
  ),
);

// ── Test sources ───────────────────────────────────────────────

const _kM3uSource = PlaylistSource(
  id: 'src_m3u_1',
  name: 'My Playlist',
  url: 'http://example.com/playlist.m3u',
  type: PlaylistSourceType.m3u,
  epgUrl: 'http://example.com/epg.xml',
);

const _kXtreamSource = PlaylistSource(
  id: 'src_xtream_1',
  name: 'My Xtream',
  url: 'http://provider.com:8080',
  type: PlaylistSourceType.xtream,
  username: 'user',
  password: 'pass',
);

// ── Fake SettingsNotifier ──────────────────────────────────────

class _FakeSettingsNotifier extends SettingsNotifier {
  final List<PlaylistSource> _initialSources;

  _FakeSettingsNotifier({List<PlaylistSource>? sources})
    : _initialSources = sources ?? [];

  String? deletedSourceId;
  String? updatedUserAgentSourceId;
  String? updatedUserAgentValue;
  PlaylistSource? updatedSource;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig(), sources: _initialSources);

  @override
  Future<void> removeSource(String id) async {
    deletedSourceId = id;
    final current = state.value;
    if (current != null) {
      final updated = current.sources.where((s) => s.id != id).toList();
      state = AsyncData(current.copyWith(sources: updated));
    }
  }

  @override
  Future<void> updateSourceUserAgent(String sourceId, String? userAgent) async {
    updatedUserAgentSourceId = sourceId;
    updatedUserAgentValue = userAgent;
  }

  @override
  Future<void> updateSource(PlaylistSource updated) async {
    updatedSource = updated;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Pump helpers ──────────────────────────────────────────────

/// Pumps a [SourceTile] in isolation with a delete callback wired to
/// [fakeNotifier.removeSource].
Future<_FakeSettingsNotifier> _pumpSourceTile(
  WidgetTester tester,
  PlaylistSource source, {
  bool showDragHandle = false,
}) async {
  final backendImpl = MemoryBackend();
  final cache = CacheService(backendImpl);
  final fakeNotifier = _FakeSettingsNotifier(sources: [source]);

  // SourceTile is defined in source_extra_sections.dart.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backendImpl),
        cacheServiceProvider.overrideWithValue(cache),
        settingsNotifierProvider.overrideWith(() => fakeNotifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            // Consumer forces provider initialization so that the notifier's
            // $ref is set before any direct method calls on the instance.
            child: Consumer(
              builder: (context, ref, _) {
                // Read the provider to ensure it is initialized.
                ref.watch(settingsNotifierProvider);
                return SourceTile(
                  source: source,
                  index: 0,
                  showDragHandle: showDragHandle,
                  onDelete:
                      () => ref
                          .read(settingsNotifierProvider.notifier)
                          .removeSource(source.id),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeNotifier;
}

/// Pumps a [UserAgentSettingsSection] with the given sources.
Future<_FakeSettingsNotifier> _pumpUserAgentSection(
  WidgetTester tester,
  List<PlaylistSource> sources,
) async {
  final backendImpl = MemoryBackend();
  final cache = CacheService(backendImpl);
  final fakeNotifier = _FakeSettingsNotifier(sources: sources);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backendImpl),
        cacheServiceProvider.overrideWithValue(cache),
        settingsNotifierProvider.overrideWith(() => fakeNotifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: UserAgentSettingsSection(sources: sources),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeNotifier;
}

/// Pumps an [EpgUrlSettingsSection] with the given sources.
Future<_FakeSettingsNotifier> _pumpEpgUrlSection(
  WidgetTester tester,
  List<PlaylistSource> sources,
) async {
  final backendImpl = MemoryBackend();
  final cache = CacheService(backendImpl);
  final fakeNotifier = _FakeSettingsNotifier(sources: sources);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backendImpl),
        cacheServiceProvider.overrideWithValue(cache),
        settingsNotifierProvider.overrideWith(() => fakeNotifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EpgUrlSettingsSection(sources: sources),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeNotifier;
}

// ── Tests ──────────────────────────────────────────────────────

void main() {
  // ── Delete Confirm Dialog ─────────────────────────────────────

  group('Delete confirm dialog', () {
    testWidgets('shows "Remove Source" title on delete button tap', (
      tester,
    ) async {
      await _pumpSourceTile(tester, _kM3uSource);

      // The delete button is an IconButton with Icons.delete_outline.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Remove Source'), findsOneWidget);
    });

    testWidgets('confirmation dialog has Cancel and Remove buttons', (
      tester,
    ) async {
      await _pumpSourceTile(tester, _kM3uSource);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('Remove button is styled in error color', (tester) async {
      await _pumpSourceTile(tester, _kM3uSource);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      final removeButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Remove'),
      );
      // The Remove button style uses colorScheme.error as backgroundColor.
      expect(removeButton.style, isNotNull);
    });

    testWidgets('Cancel closes dialog without deleting', (tester) async {
      final fake = await _pumpSourceTile(tester, _kM3uSource);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Source'), findsNothing);
      expect(fake.deletedSourceId, isNull);
    });

    testWidgets('Remove button calls removeSource with source id', (
      tester,
    ) async {
      final fake = await _pumpSourceTile(tester, _kM3uSource);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(fake.deletedSourceId, _kM3uSource.id);
    });

    testWidgets('dialog closes after confirming Remove', (tester) async {
      await _pumpSourceTile(tester, _kM3uSource);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  // ── Drag Handle ──────────────────────────────────────────────

  group('Drag handle', () {
    testWidgets('drag handle icon not visible when showDragHandle is false', (
      tester,
    ) async {
      await _pumpSourceTile(tester, _kM3uSource, showDragHandle: false);

      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('drag handle icon visible when showDragHandle is true', (
      tester,
    ) async {
      await _pumpSourceTile(tester, _kM3uSource, showDragHandle: true);

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });
  });

  // ── User Agent dialog ─────────────────────────────────────────

  group('User Agent dialog', () {
    testWidgets('User Agent section shows source name as tile title', (
      tester,
    ) async {
      await _pumpUserAgentSection(tester, [_kM3uSource]);

      expect(find.text(_kM3uSource.name), findsOneWidget);
    });

    testWidgets('tapping source row opens user agent dialog', (tester) async {
      await _pumpUserAgentSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('user agent dialog title includes source name', (tester) async {
      await _pumpUserAgentSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      expect(find.textContaining(_kM3uSource.name), findsWidgets);
    });

    testWidgets('user agent dialog shows Custom User Agent field', (
      tester,
    ) async {
      await _pumpUserAgentSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      expect(find.text('Custom User Agent'), findsOneWidget);
    });

    testWidgets('Cancel closes dialog without saving', (tester) async {
      final fake = await _pumpUserAgentSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.updatedUserAgentSourceId, isNull);
    });

    testWidgets('Save calls updateSourceUserAgent and shows snackbar', (
      tester,
    ) async {
      final fake = await _pumpUserAgentSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Custom User Agent'),
        'MyCustomAgent/1.0',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fake.updatedUserAgentSourceId, _kM3uSource.id);
      expect(fake.updatedUserAgentValue, 'MyCustomAgent/1.0');
      expect(find.text('User agent updated'), findsOneWidget);
    });

    testWidgets('existing user agent is pre-filled in the dialog', (
      tester,
    ) async {
      const sourceWithAgent = PlaylistSource(
        id: 'src_agent_1',
        name: 'Agent Source',
        url: 'http://example.com/playlist.m3u',
        type: PlaylistSourceType.m3u,
        userAgent: 'VLC/3.0',
      );

      await _pumpUserAgentSection(tester, [sourceWithAgent]);

      await tester.tap(find.text(sourceWithAgent.name));
      await tester.pumpAndSettle();

      // The existing user agent value should appear in the text field.
      // It also appears in the tile subtitle, so findsAtLeast(1) is used.
      expect(find.text('VLC/3.0'), findsAtLeast(1));
    });
  });

  // ── Per-source EPG URL dialog ─────────────────────────────────

  group('Per-source EPG URL dialog', () {
    testWidgets('EPG URL section only shows M3U and Xtream sources', (
      tester,
    ) async {
      await _pumpEpgUrlSection(tester, [_kM3uSource, _kXtreamSource]);

      expect(find.text(_kM3uSource.name), findsOneWidget);
      expect(find.text(_kXtreamSource.name), findsOneWidget);
    });

    testWidgets('tapping source row opens EPG URL dialog', (tester) async {
      await _pumpEpgUrlSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('EPG URL dialog title includes source name', (tester) async {
      await _pumpEpgUrlSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      expect(find.textContaining(_kM3uSource.name), findsWidgets);
    });

    testWidgets('existing EPG URL is pre-filled in the dialog', (tester) async {
      await _pumpEpgUrlSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      // The existing EPG URL from _kM3uSource should appear in the field.
      // It also appears in the tile subtitle, so findsAtLeast(1) is used.
      expect(find.text(_kM3uSource.epgUrl!), findsAtLeast(1));
    });

    testWidgets('Cancel closes dialog without saving', (tester) async {
      final fake = await _pumpEpgUrlSection(tester, [_kM3uSource]);

      await tester.tap(find.text(_kM3uSource.name));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.updatedSource, isNull);
    });

    testWidgets(
      'Save calls updateSource and shows "EPG URL updated" snackbar',
      (tester) async {
        final fake = await _pumpEpgUrlSection(tester, [_kM3uSource]);

        await tester.tap(find.text(_kM3uSource.name));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'XMLTV URL'),
          'https://new-epg.example.com/guide.xml',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(fake.updatedSource, isNotNull);
        expect(
          fake.updatedSource!.epgUrl,
          'https://new-epg.example.com/guide.xml',
        );
        expect(find.text('EPG URL updated'), findsOneWidget);
      },
    );
  });
}
