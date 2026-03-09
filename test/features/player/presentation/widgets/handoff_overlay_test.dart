import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/handoff_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Notifier that starts with handoff in progress.
class _ActiveHandoffNotifier extends HandoffInProgressNotifier {
  @override
  bool build() => true;
}

void main() {
  group('HandoffOverlay', () {
    testWidgets('renders nothing when handoff not in progress', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HandoffOverlay())),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows spinner when handoff in progress', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            handoffInProgressProvider.overrideWith(
              () => _ActiveHandoffNotifier(),
            ),
          ],
          child: const MaterialApp(home: HandoffOverlay()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
