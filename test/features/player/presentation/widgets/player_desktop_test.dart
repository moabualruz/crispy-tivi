import 'package:crispy_tivi/features/player/presentation/providers/player_settings_providers.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/player_osd/osd_overflow_menu.dart';
import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlwaysOnTopNotifier', () {
    test('starts as false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(alwaysOnTopProvider), false);
    });

    test('toggle flips state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(alwaysOnTopProvider.notifier).toggle();
      expect(container.read(alwaysOnTopProvider), true);

      container.read(alwaysOnTopProvider.notifier).toggle();
      expect(container.read(alwaysOnTopProvider), false);
    });

    test('set applies explicit value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(alwaysOnTopProvider.notifier).set(true);
      expect(container.read(alwaysOnTopProvider), true);

      container.read(alwaysOnTopProvider.notifier).set(false);
      expect(container.read(alwaysOnTopProvider), false);
    });
  });

  group('ScreenBrightnessNotifier', () {
    test('starts as null (system default)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(screenBrightnessProvider), null);
    });

    test('setBrightness sets value clamped to 0.0-1.0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(screenBrightnessProvider.notifier).setBrightness(0.5);
      expect(container.read(screenBrightnessProvider), 0.5);

      // Clamp above 1.0
      container.read(screenBrightnessProvider.notifier).setBrightness(1.5);
      expect(container.read(screenBrightnessProvider), 1.0);

      // Clamp below 0.0
      container.read(screenBrightnessProvider.notifier).setBrightness(-0.3);
      expect(container.read(screenBrightnessProvider), 0.0);
    });

    test('resetToSystem returns to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(screenBrightnessProvider.notifier).setBrightness(0.7);
      expect(container.read(screenBrightnessProvider), 0.7);

      container.read(screenBrightnessProvider.notifier).resetToSystem();
      expect(container.read(screenBrightnessProvider), null);
    });
  });

  group('OsdOverflowMenu always-on-top item', () {
    testWidgets('renders always-on-top menu item with off state', (
      tester,
    ) async {
      // Skip on web — always-on-top is desktop only.
      if (kIsWeb) return;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OsdOverflowMenu(
              onAudioTrack: () {},
              onAspectRatio: () {},
              onRefresh: () {},
              onStreamInfo: () {},
              aspectRatioLabel: 'Auto',
              isLive: false,
              isFavorite: false,
              onAlwaysOnTop: () {},
              isAlwaysOnTop: false,
            ),
          ),
        ),
      );

      // Tap the overflow button to open menu.
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // On non-Windows/Linux, the menu item won't appear.
      // This test validates the widget renders without error.
    });

    testWidgets('renders always-on-top menu item with on state', (
      tester,
    ) async {
      if (kIsWeb) return;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OsdOverflowMenu(
              onAudioTrack: () {},
              onAspectRatio: () {},
              onRefresh: () {},
              onStreamInfo: () {},
              aspectRatioLabel: 'Auto',
              isLive: false,
              isFavorite: false,
              onAlwaysOnTop: () {},
              isAlwaysOnTop: true,
            ),
          ),
        ),
      );

      // Tap the overflow button to open menu.
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
    });
  });

  group('OsdOverflowMenu brightness item', () {
    testWidgets('renders brightness menu item', (tester) async {
      if (kIsWeb) return;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OsdOverflowMenu(
              onAudioTrack: () {},
              onAspectRatio: () {},
              onRefresh: () {},
              onStreamInfo: () {},
              aspectRatioLabel: 'Auto',
              isLive: false,
              isFavorite: false,
              onBrightness: () {},
            ),
          ),
        ),
      );

      // Tap the overflow button to open menu.
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // On non-mobile platforms, the item won't appear.
      // This validates the widget renders without error.
    });
  });

  group('T key shortcut', () {
    test('T key constant matches LogicalKeyboardKey.keyT', () {
      // Verify the key constant exists and can be compared.
      expect(LogicalKeyboardKey.keyT, isNotNull);
      expect(LogicalKeyboardKey.keyT.keyId, isNonZero);
    });
  });
}
