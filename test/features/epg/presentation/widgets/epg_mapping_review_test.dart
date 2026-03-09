import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:crispy_tivi/features/epg/presentation/widgets/'
    'epg_mapping_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryBackend backend;
  late CacheService cache;

  setUp(() {
    backend = MemoryBackend();
    cache = CacheService(backend);
  });

  Widget buildApp({required Widget child}) {
    return ProviderScope(
      overrides: [cacheServiceProvider.overrideWithValue(cache)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('EpgMappingReviewSheet', () {
    testWidgets('shows empty state when no suggestions', (tester) async {
      await tester.pumpWidget(buildApp(child: const EpgMappingReviewSheet()));
      await tester.pumpAndSettle();

      expect(find.text('No pending suggestions'), findsOneWidget);
      expect(find.text('EPG Mapping Suggestions'), findsOneWidget);
    });

    testWidgets('shows suggestion tiles', (tester) async {
      await backend.saveEpgMapping({
        'channel_id': 'ch1',
        'epg_channel_id': 'epg1',
        'confidence': 0.55,
        'source': 'fuzzy',
        'locked': false,
        'created_at': 1000,
      });

      await tester.pumpWidget(buildApp(child: const EpgMappingReviewSheet()));
      await tester.pumpAndSettle();

      expect(find.text('ch1'), findsOneWidget);
      expect(find.textContaining('epg1'), findsOneWidget);
      expect(find.textContaining('55%'), findsOneWidget);
      expect(find.textContaining('fuzzy'), findsOneWidget);
    });

    testWidgets('accept locks mapping and removes from list', (tester) async {
      await backend.saveEpgMapping({
        'channel_id': 'ch1',
        'epg_channel_id': 'epg1',
        'confidence': 0.55,
        'source': 'fuzzy',
        'locked': false,
        'created_at': 1000,
      });

      await tester.pumpWidget(buildApp(child: const EpgMappingReviewSheet()));
      await tester.pumpAndSettle();

      // Tap accept button (check icon)
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Should show empty state after accepting
      expect(find.text('No pending suggestions'), findsOneWidget);

      // Verify mapping is locked in backend
      final mappings = await backend.getEpgMappings();
      expect(mappings.length, 1);
      expect(mappings[0]['locked'], true);
    });

    testWidgets('reject deletes mapping', (tester) async {
      await backend.saveEpgMapping({
        'channel_id': 'ch1',
        'epg_channel_id': 'epg1',
        'confidence': 0.55,
        'source': 'fuzzy',
        'locked': false,
        'created_at': 1000,
      });

      await tester.pumpWidget(buildApp(child: const EpgMappingReviewSheet()));
      await tester.pumpAndSettle();

      // Tap reject button (close icon)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should show empty state after rejecting
      expect(find.text('No pending suggestions'), findsOneWidget);

      // Verify mapping is deleted from backend
      final mappings = await backend.getEpgMappings();
      expect(mappings, isEmpty);
    });

    testWidgets('does not show high-confidence mappings', (tester) async {
      // High confidence (>= 0.70) - auto-applied, not pending
      await backend.saveEpgMapping({
        'channel_id': 'ch_high',
        'epg_channel_id': 'epg_high',
        'confidence': 0.85,
        'source': 'tvg_id_exact',
        'locked': false,
        'created_at': 1000,
      });

      await tester.pumpWidget(buildApp(child: const EpgMappingReviewSheet()));
      await tester.pumpAndSettle();

      expect(find.text('No pending suggestions'), findsOneWidget);
      expect(find.text('ch_high'), findsNothing);
    });

    testWidgets('does not show locked suggestions', (tester) async {
      await backend.saveEpgMapping({
        'channel_id': 'ch_locked',
        'epg_channel_id': 'epg_locked',
        'confidence': 0.55,
        'source': 'fuzzy',
        'locked': true,
        'created_at': 1000,
      });

      await tester.pumpWidget(buildApp(child: const EpgMappingReviewSheet()));
      await tester.pumpAndSettle();

      expect(find.text('No pending suggestions'), findsOneWidget);
      expect(find.text('ch_locked'), findsNothing);
    });

    testWidgets('shows multiple suggestions sorted by display', (tester) async {
      await backend.saveEpgMapping({
        'channel_id': 'ch_a',
        'epg_channel_id': 'epg_a',
        'confidence': 0.60,
        'source': 'fuzzy',
        'locked': false,
        'created_at': 1000,
      });
      await backend.saveEpgMapping({
        'channel_id': 'ch_b',
        'epg_channel_id': 'epg_b',
        'confidence': 0.45,
        'source': 'fuzzy',
        'locked': false,
        'created_at': 2000,
      });

      await tester.pumpWidget(buildApp(child: const EpgMappingReviewSheet()));
      await tester.pumpAndSettle();

      expect(find.text('ch_a'), findsOneWidget);
      expect(find.text('ch_b'), findsOneWidget);
    });
  });
}
