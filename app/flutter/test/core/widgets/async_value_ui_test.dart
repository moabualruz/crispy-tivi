import 'package:crispy_tivi/core/widgets/async_value_ui.dart';
import 'package:crispy_tivi/core/widgets/error_boundary.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] in the minimum widget tree needed for widget tests.
Widget _testApp(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  group('AsyncValueUi', () {
    group('whenUi()', () {
      testWidgets('renders data widget on success', (tester) async {
        const value = AsyncValue<String>.data('hello');

        await tester.pumpWidget(
          _testApp(Builder(builder: (_) => value.whenUi(data: (v) => Text(v)))),
        );

        expect(find.text('hello'), findsOneWidget);
      });

      testWidgets('renders ErrorBoundary on error', (tester) async {
        final value = AsyncValue<String>.error(
          Exception('boom'),
          StackTrace.current,
        );

        await tester.pumpWidget(
          _testApp(Builder(builder: (_) => value.whenUi(data: (v) => Text(v)))),
        );

        expect(find.byType(ErrorBoundary), findsOneWidget);
        expect(find.textContaining('boom'), findsWidgets);
      });

      testWidgets('renders retry button when onRetry provided', (tester) async {
        var retried = false;
        final value = AsyncValue<String>.error(
          Exception('fail'),
          StackTrace.current,
        );

        await tester.pumpWidget(
          _testApp(
            Builder(
              builder:
                  (_) => value.whenUi(
                    data: (v) => Text(v),
                    onRetry: () => retried = true,
                  ),
            ),
          ),
        );

        expect(find.byType(ErrorBoundary), findsOneWidget);
        final retryButton = find.byIcon(Icons.refresh);
        expect(retryButton, findsOneWidget);
        await tester.tap(retryButton);
        expect(retried, isTrue);
      });

      testWidgets('renders error without crash when onRetry is null', (
        tester,
      ) async {
        final value = AsyncValue<String>.error(
          Exception('no-retry'),
          StackTrace.current,
        );

        await tester.pumpWidget(
          _testApp(Builder(builder: (_) => value.whenUi(data: (v) => Text(v)))),
        );

        expect(find.byType(ErrorBoundary), findsOneWidget);
        // No retry button when onRetry is null.
        expect(find.byIcon(Icons.refresh), findsNothing);
      });
    });

    group('whenShrink()', () {
      testWidgets('returns SizedBox.shrink on error', (tester) async {
        final value = AsyncValue<String>.error(
          Exception('silent'),
          StackTrace.current,
        );

        await tester.pumpWidget(
          _testApp(
            Builder(builder: (_) => value.whenShrink(data: (v) => Text(v))),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(ErrorBoundary), findsNothing);
      });

      testWidgets('returns SizedBox.shrink on loading', (tester) async {
        const value = AsyncValue<String>.loading();

        await tester.pumpWidget(
          _testApp(
            Builder(builder: (_) => value.whenShrink(data: (v) => Text(v))),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(ErrorBoundary), findsNothing);
      });
    });
  });
}
