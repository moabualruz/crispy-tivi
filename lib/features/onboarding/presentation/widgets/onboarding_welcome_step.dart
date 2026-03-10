import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/crispy_logo.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../providers/onboarding_notifier.dart';

/// First step of the onboarding wizard — branding + entry point.
///
/// Displays the app icon, welcome copy, and a "Get Started" button
/// that advances to the [OnboardingStep.typePicker] step.
class OnboardingWelcomeStep extends ConsumerWidget {
  const OnboardingWelcomeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CrispyLogo(size: 72),
            const SizedBox(height: CrispySpacing.lg),
            Text(
              context.l10n.onboardingWelcome,
              style: textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              context.l10n.onboardingAddSource,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.xxl),
            Semantics(
              button: true,
              label: 'Get started with setup',
              child: FocusWrapper(
                autofocus: true,
                onSelect:
                    () => ref
                        .read(onboardingProvider.notifier)
                        .goToStep(OnboardingStep.typePicker),
                child: FilledButton(
                  onPressed:
                      () => ref
                          .read(onboardingProvider.notifier)
                          .goToStep(OnboardingStep.typePicker),
                  child: Text(context.l10n.onboardingStartWatching),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
