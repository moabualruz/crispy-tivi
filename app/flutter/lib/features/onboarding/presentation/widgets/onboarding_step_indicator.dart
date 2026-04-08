import 'package:flutter/material.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';

/// A pill-style step indicator for the onboarding wizard.
///
/// Renders [totalSteps] dots in a row. The active step is displayed
/// as a wide pill (24 × 8 dp, primary colour); inactive steps are
/// compact circles (8 × 8 dp, muted surface colour).
class OnboardingStepIndicator extends StatelessWidget {
  const OnboardingStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  /// Zero-based index of the currently active step.
  final int currentStep;

  /// Total number of dots to show. Defaults to 3.
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Step ${currentStep + 1} of $totalSteps',
      child: Row(
        key: TestKeys.onboardingStepIndicator,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalSteps, (index) {
          final isActive = index == currentStep;
          return AnimatedContainer(
            duration: CrispyAnimation.fast,
            curve: CrispyAnimation.enterCurve,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color:
                  isActive
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(CrispyRadius.xs),
            ),
          );
        }),
      ),
    );
  }
}
