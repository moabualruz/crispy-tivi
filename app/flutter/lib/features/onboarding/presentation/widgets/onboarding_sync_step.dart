import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../providers/onboarding_notifier.dart';

/// Fourth step of the onboarding wizard — sync progress and result.
///
/// Switches between three visual states based on [SyncStatus]:
/// - **syncing**: progress indicator + descriptive text
/// - **success**: check icon + channel count + "Enter App" button
/// - **error**: error icon + message + retry / edit buttons
class OnboardingSyncStep extends ConsumerWidget {
  const OnboardingSyncStep({super.key});

  void _enterApp(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsNotifierProvider).value;
    final defaultScreen = settings?.defaultScreen ?? 'home';
    context.go(defaultScreen == 'live_tv' ? AppRoutes.tv : AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(onboardingProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.lg),
        child: switch (state.syncStatus) {
          SyncStatus.syncing => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: CrispySpacing.lg),
              Text(
                context.l10n.onboardingSyncing,
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          SyncStatus.success => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 72, color: Colors.green),
              const SizedBox(height: CrispySpacing.md),
              Text(
                context.l10n.onboardingChannelsLoaded(state.channelCount),
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (state.vodCount > 0) ...[
                const SizedBox(height: CrispySpacing.sm),
                Text(
                  'Also synced ${state.vodCount} movies/series items.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: CrispySpacing.xxl),
              Semantics(
                button: true,
                label: context.l10n.onboardingEnterAppLabel,
                child: FocusWrapper(
                  autofocus: true,
                  onSelect: () => _enterApp(context, ref),
                  child: FilledButton(
                    onPressed: () => _enterApp(context, ref),
                    child: Text(context.l10n.onboardingEnterApp),
                  ),
                ),
              ),
            ],
          ),
          SyncStatus.error => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 72, color: colorScheme.error),
              const SizedBox(height: CrispySpacing.md),
              Text(
                context.l10n.onboardingCouldNotConnect,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (state.syncErrorMessage != null) ...[
                const SizedBox(height: CrispySpacing.sm),
                Text(
                  state.syncErrorMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: CrispySpacing.lg),
              Semantics(
                button: true,
                label: context.l10n.onboardingRetryLabel,
                child: FocusWrapper(
                  autofocus: true,
                  onSelect: () => notifier.retrySync(),
                  child: FilledButton(
                    onPressed: () => notifier.retrySync(),
                    child: Text(context.l10n.commonRetry),
                  ),
                ),
              ),
              const SizedBox(height: CrispySpacing.sm),
              Semantics(
                button: true,
                label: context.l10n.onboardingEditSource,
                child: TextButton(
                  onPressed: () => notifier.editSource(),
                  child: Text(context.l10n.onboardingEditSource),
                ),
              ),
            ],
          ),
          SyncStatus.idle => const SizedBox.shrink(),
        },
      ),
    );
  }
}
