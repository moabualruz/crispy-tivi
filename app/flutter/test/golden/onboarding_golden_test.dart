import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/onboarding/presentation/providers/onboarding_notifier.dart';
import 'package:crispy_tivi/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OnboardingScreen golden — compact Welcome step centered card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
          onboardingProvider.overrideWith(() => _WelcomeStepNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding_welcome.png'),
    );
  });

  testWidgets(
    'OnboardingScreen golden — compact Type Picker step source type cards',
    (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testBackend = MemoryBackend();
      final testCache = CacheService(testBackend);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crispyBackendProvider.overrideWithValue(testBackend),
            cacheServiceProvider.overrideWithValue(testCache),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.fromThemeState(const ThemeState()).theme,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance from Welcome → TypePicker by tapping "Get Started".
      // The welcome step renders a button that triggers goToStep(typePicker).
      // If no such button exists, we drive the notifier directly.
      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)),
      );
      providerContainer
          .read(onboardingProvider.notifier)
          .goToStep(OnboardingStep.typePicker);

      // Animate the PageView transition.
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(OnboardingScreen),
        matchesGoldenFile('goldens/onboarding_type_picker.png'),
      );
    },
  );
}

// ── Fake notifiers ────────────────────────────────────────────────────────────

class _WelcomeStepNotifier extends OnboardingNotifier {
  @override
  OnboardingState build() {
    ref.onDispose(() {});
    return const OnboardingState(step: OnboardingStep.welcome);
  }
}
