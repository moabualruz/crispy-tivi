import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/playlist_source.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../providers/onboarding_notifier.dart';

/// Second step of the onboarding wizard — source type selection.
///
/// Presents three glassmorphic cards (M3U, Xtream Codes, Stalker
/// Portal). On compact layouts (<840 dp) the cards stack vertically;
/// on expanded layouts they sit side-by-side in a row.
class OnboardingTypePickerStep extends ConsumerWidget {
  const OnboardingTypePickerStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final isExpanded = width >= 840;
    final notifier = ref.read(onboardingProvider.notifier);

    final cards = [
      _TypeCard(
        key: TestKeys.onboardingSourceType('m3u'),
        icon: Icons.playlist_play,
        title: 'M3U Playlist',
        subtitle: 'Add via URL or file link',
        autofocus: true,
        onTap: () => notifier.selectSourceType(PlaylistSourceType.m3u),
      ),
      _TypeCard(
        key: TestKeys.onboardingSourceType('xtream'),
        icon: Icons.dns,
        title: 'Xtream Codes',
        subtitle: 'Server URL with login credentials',
        onTap: () => notifier.selectSourceType(PlaylistSourceType.xtream),
      ),
      _TypeCard(
        key: TestKeys.onboardingSourceType('stalker'),
        icon: Icons.router,
        title: 'Stalker Portal',
        subtitle: 'Portal URL with MAC address',
        onTap:
            () => notifier.selectSourceType(PlaylistSourceType.stalkerPortal),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your source type',
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CrispySpacing.lg),
          if (isExpanded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cards
                  .map((card) => Expanded(child: card))
                  .toList(growable: false),
            )
          else
            Column(children: cards),
          const SizedBox(height: CrispySpacing.lg),
          Center(
            child: Semantics(
              button: true,
              label: 'Go back to previous step',
              child: TextButton.icon(
                onPressed: () => ref.read(onboardingProvider.notifier).goBack(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glassmorphic card representing a single source type.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(CrispySpacing.xs),
      child: Semantics(
        button: true,
        label: 'Select $title source type',
        child: FocusWrapper(
          autofocus: autofocus,
          onSelect: onTap,
          borderRadius: CrispyRadius.lg,
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CrispyRadius.lg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(CrispySpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(CrispyRadius.lg),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 40, color: colorScheme.primary),
                      const SizedBox(height: CrispySpacing.sm),
                      Text(
                        title,
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: CrispySpacing.xs),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
