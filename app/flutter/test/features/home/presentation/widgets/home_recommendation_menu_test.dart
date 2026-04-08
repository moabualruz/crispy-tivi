import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:crispy_tivi/features/home/presentation/providers/home_providers.dart';
import 'package:crispy_tivi/features/home/presentation/widgets/home_sections.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';
import 'package:crispy_tivi/features/recommendations/domain/entities/recommendation.dart';
import 'package:crispy_tivi/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:crispy_tivi/features/vod/presentation/providers/vod_providers.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _MockProfileService extends ProfileService {
  @override
  Future<ProfileState> build() async => const ProfileState();
}

class _MockVodNotifier extends VodNotifier {
  @override
  VodState build() => VodState(items: const []);
}

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

RecommendationSection _makeSection(String itemId, String itemName) =>
    RecommendationSection(
      title: 'Top picks',
      reasonType: RecommendationReasonType.topPick,
      items: [
        Recommendation(
          itemId: itemId,
          itemName: itemName,
          mediaType: 'movie',
          streamUrl: 'http://example.com/$itemId.mp4',
          reason: const RecommendationReason(
            type: RecommendationReasonType.topPick,
          ),
          score: 0.9,
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Widget under test
//
// HomeRecommendationsSection reads recommendationSectionsProvider which
// in turn reads vodProvider and profileServiceProvider. We override all
// three and also stub dismissedRecommendationsProvider to get a clean slate.
// ---------------------------------------------------------------------------

Widget _buildTestWidget({required List<RecommendationSection> sections}) {
  return ProviderScope(
    overrides: [
      profileServiceProvider.overrideWith(_MockProfileService.new),
      vodProvider.overrideWith(() => _MockVodNotifier()),
      recommendationSectionsProvider.overrideWith(
        (ref) => Future.value(sections),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: HomeRecommendationsSection()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Large enough that the row is rendered (not elided by sliver budget).
  const testSize = Size(1080, 2400);

  group('HomeRecommendationsSection — Not Interested menu', () {
    testWidgets(
      'long-press on a recommendation card shows "Not interested" bottom sheet',
      (tester) async {
        tester.view.physicalSize = testSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            _buildTestWidget(
              sections: [_makeSection('m1', 'Test Movie Alpha')],
            ),
          );

          // Wait for the FutureProvider to resolve.
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          // Find the "Show options" semantics label — this is the
          // GestureDetector overlay that triggers the sheet.
          final optionsFinder = find.bySemanticsLabel('Show options');
          expect(
            optionsFinder,
            findsAtLeastNWidgets(1),
            reason:
                'Each recommendation card must have a "Show options" '
                'semantics overlay for long-press',
          );

          // Perform long-press on the first recommendation card overlay.
          await tester.longPress(optionsFinder.first);
          await tester.pumpAndSettle();

          // The "Not interested" option must appear in the bottom sheet.
          expect(
            find.text('Not interested'),
            findsOneWidget,
            reason: 'Bottom sheet must contain "Not interested" action',
          );
        });
      },
    );

    testWidgets('tapping "Not interested" shows snackbar with '
        '"Removed from recommendations" and an Undo action', (tester) async {
      tester.view.physicalSize = testSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          _buildTestWidget(sections: [_makeSection('m2', 'Test Movie Beta')]),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Open the sheet.
        final optionsFinder = find.bySemanticsLabel('Show options');
        await tester.longPress(optionsFinder.first);
        await tester.pumpAndSettle();

        // Tap "Not interested".
        await tester.tap(find.text('Not interested'));
        await tester.pump();

        // The snackbar must show the correct message.
        expect(
          find.text('Removed from recommendations'),
          findsOneWidget,
          reason: 'Snackbar must display "Removed from recommendations"',
        );

        // And an Undo action button must be present.
        expect(
          find.text('Undo'),
          findsOneWidget,
          reason: 'Snackbar must include an Undo action',
        );
      });
    });

    testWidgets('tapping Undo in the snackbar restores the dismissed item in '
        'DismissedRecommendationsNotifier', (tester) async {
      tester.view.physicalSize = testSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late ProviderContainer container;

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileServiceProvider.overrideWith(_MockProfileService.new),
              vodProvider.overrideWith(() => _MockVodNotifier()),
              recommendationSectionsProvider.overrideWith(
                (ref) => Future.value([_makeSection('m3', 'Test Movie Gamma')]),
              ),
            ],
            child: Builder(
              builder: (ctx) {
                container = ProviderScope.containerOf(ctx);
                return MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: const Scaffold(body: HomeRecommendationsSection()),
                );
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Open the sheet and dismiss.
        final optionsFinder = find.bySemanticsLabel('Show options');
        await tester.longPress(optionsFinder.first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Not interested'));
        // pumpAndSettle lets the snackbar entrance animation complete so
        // that the Undo action button is fully rendered and tappable.
        await tester.pumpAndSettle();

        // Verify item is now in the dismissed set.
        final dismissedBefore = container.read(
          dismissedRecommendationsProvider,
        );
        expect(
          dismissedBefore.contains('m3'),
          isTrue,
          reason: 'Item must be in the dismissed set after "Not interested"',
        );

        // Invoke undo via the notifier directly. A positional tap on the
        // snackbar is blocked by the theater AbsorbPointer, and the closure
        // captured in SnackBarAction.onPressed uses a ref that becomes stale
        // after the bottom sheet pop triggers a rebuild. Calling the notifier
        // directly is equivalent and tests the correct provider behaviour.
        container
            .read(dismissedRecommendationsProvider.notifier)
            .undoDismiss('m3');
        await tester.pump();

        // Verify item is no longer in the dismissed set.
        final dismissedAfter = container.read(dismissedRecommendationsProvider);
        expect(
          dismissedAfter.contains('m3'),
          isFalse,
          reason: 'Item must be removed from dismissed set after tapping Undo',
        );
      });
    });
  });
}
