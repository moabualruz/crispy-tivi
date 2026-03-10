import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/'
    'source_extra_sections.dart';

// ── Minimal AppConfig for tests ───────────────────────────────

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

// ── Fake SettingsNotifier ─────────────────────────────────────

class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  _FakeSettingsNotifier(this._initial);

  final SettingsState _initial;

  late SettingsState _state;

  List<String>? lastSetHiddenGroups;

  @override
  Future<SettingsState> build() async {
    _state = _initial;
    return _state;
  }

  @override
  Future<void> setHiddenGroups(List<String> groups) async {
    lastSetHiddenGroups = groups;
    _state = _state.copyWith(hiddenGroups: groups);
    state = AsyncData(_state);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Pump helper ───────────────────────────────────────────────

/// Pumps [ContentFilterSettingsSection] with the given
/// [hiddenGroups] and a [MemoryBackend] pre-seeded with
/// [categoryMap].
Future<_FakeSettingsNotifier> _pump(
  WidgetTester tester, {
  List<String> hiddenGroups = const [],
  Map<String, List<String>> categoryMap = const {},
}) async {
  final backend = MemoryBackend();
  if (categoryMap.isNotEmpty) {
    await backend.saveCategories(categoryMap);
  }
  final cache = CacheService(backend);
  final settings = SettingsState(
    config: _minimalConfig(),
    hiddenGroups: hiddenGroups,
  );
  final fakeNotifier = _FakeSettingsNotifier(settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsNotifierProvider.overrideWith(() => fakeNotifier),
        cacheServiceProvider.overrideWithValue(cache),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContentFilterSettingsSection(hiddenGroups: hiddenGroups),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeNotifier;
}

// ── Tests ─────────────────────────────────────────────────────

void main() {
  group('Hidden Categories', () {
    // ── Subtitle text ──────────────────────────────────────────

    testWidgets('renders "Hidden Categories" tile with correct title', (
      tester,
    ) async {
      await _pump(tester, hiddenGroups: []);

      expect(find.text('Hidden Categories'), findsOneWidget);
    });

    testWidgets(
      'subtitle shows "No categories hidden" when hiddenGroups is empty',
      (tester) async {
        await _pump(tester, hiddenGroups: []);

        expect(find.text('No categories hidden'), findsOneWidget);
      },
    );

    testWidgets('subtitle shows "1 hidden" when one group is hidden', (
      tester,
    ) async {
      await _pump(tester, hiddenGroups: ['Sports']);

      expect(find.text('1 hidden'), findsOneWidget);
    });

    testWidgets('subtitle shows "3 hidden" when three groups are hidden', (
      tester,
    ) async {
      await _pump(tester, hiddenGroups: ['Sports', 'News', 'Kids']);

      expect(find.text('3 hidden'), findsOneWidget);
    });

    testWidgets('tile has a trailing chevron icon', (tester) async {
      await _pump(tester, hiddenGroups: []);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tile has a leading visibility-off icon', (tester) async {
      await _pump(tester, hiddenGroups: []);

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    // ── Empty categories → snackbar ────────────────────────────

    testWidgets('tapping tile when no categories exist shows snackbar '
        '"No categories found. Sync first."', (tester) async {
      await _pump(tester, hiddenGroups: [], categoryMap: {});

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      expect(find.text('No categories found. Sync first.'), findsOneWidget);
    });

    testWidgets('no AlertDialog is opened when categories map is empty', (
      tester,
    ) async {
      await _pump(tester, hiddenGroups: [], categoryMap: {});

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    // ── Non-empty categories → dialog ──────────────────────────

    testWidgets('tapping tile when categories exist opens AlertDialog', (
      tester,
    ) async {
      await _pump(
        tester,
        categoryMap: {
          'source1': ['Sports', 'News'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('dialog title is "Hidden Categories"', (tester) async {
      await _pump(
        tester,
        categoryMap: {
          'source1': ['Sports'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // Title appears twice: tile label + dialog title.
      expect(find.text('Hidden Categories'), findsNWidgets(2));
    });

    testWidgets('dialog lists all categories from the category map', (
      tester,
    ) async {
      await _pump(
        tester,
        categoryMap: {
          'source1': ['Sports', 'News'],
          'source2': ['Kids'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Kids'), findsOneWidget);
    });

    testWidgets(
      'dialog deduplicates categories that appear in multiple sources',
      (tester) async {
        await _pump(
          tester,
          categoryMap: {
            'source1': ['Sports', 'News'],
            'source2': ['Sports', 'Kids'],
          },
        );

        await tester.tap(find.text('Hidden Categories'));
        await tester.pumpAndSettle();

        // "Sports" exists in both sources but should appear only once.
        expect(find.text('Sports'), findsOneWidget);
      },
    );

    testWidgets('dialog shows Cancel and Apply buttons', (tester) async {
      await _pump(
        tester,
        categoryMap: {
          'source1': ['Sports'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    // ── Checkbox states ────────────────────────────────────────

    testWidgets('categories not in hiddenGroups are unchecked in dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        hiddenGroups: [],
        categoryMap: {
          'source1': ['Sports', 'News'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // All checkboxes should be unchecked (value == false).
      final checkboxes =
          tester
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .toList();
      expect(checkboxes.every((c) => c.value == false), isTrue);
    });

    testWidgets('categories in hiddenGroups are pre-checked in dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        hiddenGroups: ['Sports'],
        categoryMap: {
          'source1': ['Sports', 'News'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // Sports checkbox should be checked.
      final sportsTile = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .firstWhere((c) {
            final title = c.title;
            if (title is Text) return title.data == 'Sports';
            return false;
          });
      expect(sportsTile.value, isTrue);
    });

    testWidgets('categories NOT in hiddenGroups remain unchecked', (
      tester,
    ) async {
      await _pump(
        tester,
        hiddenGroups: ['Sports'],
        categoryMap: {
          'source1': ['Sports', 'News'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // News checkbox should be unchecked.
      final newsTile = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .firstWhere((c) {
            final title = c.title;
            if (title is Text) return title.data == 'News';
            return false;
          });
      expect(newsTile.value, isFalse);
    });

    // ── Checking / unchecking ──────────────────────────────────

    testWidgets('checking an unchecked category marks it checked in dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        hiddenGroups: [],
        categoryMap: {
          'source1': ['Sports'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // Tap the Sports checkbox row to check it.
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      final sportsTile =
          tester
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .first;
      expect(sportsTile.value, isTrue);
    });

    testWidgets('unchecking a checked category marks it unchecked in dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        hiddenGroups: ['Sports'],
        categoryMap: {
          'source1': ['Sports'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // Tap again to uncheck.
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      final sportsTile =
          tester
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .first;
      expect(sportsTile.value, isFalse);
    });

    // ── Cancel button ──────────────────────────────────────────

    testWidgets(
      'tapping Cancel closes the dialog without calling setHiddenGroups',
      (tester) async {
        final fake = await _pump(
          tester,
          hiddenGroups: [],
          categoryMap: {
            'source1': ['Sports'],
          },
        );

        await tester.tap(find.text('Hidden Categories'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(fake.lastSetHiddenGroups, isNull);
      },
    );

    // ── Apply button ───────────────────────────────────────────

    testWidgets('tapping Apply with no selection calls setHiddenGroups([])', (
      tester,
    ) async {
      final fake = await _pump(
        tester,
        hiddenGroups: [],
        categoryMap: {
          'source1': ['Sports', 'News'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // Do not check anything, just apply.
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fake.lastSetHiddenGroups, isNotNull);
      expect(fake.lastSetHiddenGroups, isEmpty);
    });

    testWidgets('tapping Apply after checking a category calls setHiddenGroups '
        'with that category', (tester) async {
      final fake = await _pump(
        tester,
        hiddenGroups: [],
        categoryMap: {
          'source1': ['Sports', 'News'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // Check "Sports".
      await tester.tap(find.text('Sports'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fake.lastSetHiddenGroups, contains('Sports'));
    });

    testWidgets('tapping Apply after unchecking a previously hidden category '
        'removes it from the persisted list', (tester) async {
      final fake = await _pump(
        tester,
        hiddenGroups: ['Sports'],
        categoryMap: {
          'source1': ['Sports', 'News'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      // Uncheck "Sports".
      await tester.tap(find.text('Sports'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fake.lastSetHiddenGroups, isNotNull);
      expect(fake.lastSetHiddenGroups, isNot(contains('Sports')));
    });

    testWidgets('tapping Apply closes the dialog', (tester) async {
      await _pump(
        tester,
        categoryMap: {
          'source1': ['Sports'],
        },
      );

      await tester.tap(find.text('Hidden Categories'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
