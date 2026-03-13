import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../providers/onboarding_notifier.dart';
import '../widgets/onboarding_form_step.dart';
import '../widgets/onboarding_step_indicator.dart';
import '../widgets/onboarding_sync_step.dart';
import '../widgets/onboarding_type_picker_step.dart';
import '../../../../core/utils/focus_restoration_service.dart';
import '../../../../core/widgets/safe_focus_scope.dart';
import '../widgets/onboarding_welcome_step.dart';

/// Root screen for the first-run onboarding wizard.
///
/// Hosts a [PageView] driven by [OnboardingNotifier.step].
/// Hardware back is blocked via [PopScope] because the wizard
/// manages its own back-navigation through the notifier.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _routePath = 'onboarding';
  late final PageController _pageController;
  bool _focusRestored = false;

  /// Maps [OnboardingStep] to a page index in the [PageView].
  ///
  /// welcome=0, typePicker=1, form=2, syncing=3.
  /// The step indicator uses a compressed mapping: syncing shares
  /// dot 2 with form (so the indicator stops at dot 2 once the
  /// form is submitted and sync begins).
  static int _stepToPageIndex(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.welcome => 0,
      OnboardingStep.typePicker => 1,
      OnboardingStep.form => 2,
      OnboardingStep.syncing => 3,
    };
  }

  /// Maps [OnboardingStep] to a step-indicator dot index.
  ///
  /// welcome=0, typePicker=1, form/syncing=2.
  static int _stepToIndicatorIndex(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.welcome => 0,
      OnboardingStep.typePicker => 1,
      OnboardingStep.form => 2,
      OnboardingStep.syncing => 2,
    };
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_focusRestored) {
      _focusRestored = true;
      restoreFocus(ref, _routePath, context);
    }
  }

  @override
  void deactivate() {
    saveFocusKey(ref, _routePath);
    super.deactivate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToStep(OnboardingStep step) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      _stepToPageIndex(step),
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentStep = ref.watch(onboardingProvider.select((s) => s.step));

    // Drive the PageView whenever the notifier step changes.
    ref.listen(onboardingProvider.select((s) => s.step), (_, step) {
      _animateToStep(step);
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: TestKeys.onboardingScreen,
        backgroundColor: colorScheme.surface,
        body: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: SafeFocusScope(
            restorationKey: 'onboarding',
            child: Stack(
              children: [
                const _GlassmorphicBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: CrispySpacing.lg),
                      OnboardingStepIndicator(
                        currentStep: _stepToIndicatorIndex(currentStep),
                      ),
                      const SizedBox(height: CrispySpacing.lg),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: const [
                            OnboardingWelcomeStep(),
                            OnboardingTypePickerStep(),
                            OnboardingFormStep(),
                            OnboardingSyncStep(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative glassmorphic background gradient matching the app's dark theme.
///
/// Renders a vertical gradient from [colorScheme.surface] to
/// [colorScheme.surfaceContainerLow] to give the wizard a layered look.
class _GlassmorphicBackground extends StatelessWidget {
  const _GlassmorphicBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
        ),
      ),
    );
  }
}
