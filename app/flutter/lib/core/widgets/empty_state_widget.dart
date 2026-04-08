import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';
import '../theme/crispy_spacing.dart';

/// Standardised empty-state placeholder used across all
/// content screens (Live TV, EPG, VOD, Series, etc.).
///
/// Shows an icon, title, description, and an optional
/// "Go to Settings" action button.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    this.description,
    this.showSettingsButton = false,
    this.onRefresh,
    super.key,
  });

  /// Large centred icon.
  final IconData icon;

  /// Primary message (e.g. "No channels found").
  final String title;

  /// Secondary hint (e.g. "Add a playlist source").
  final String? description;

  /// Whether to show a "Go to Settings" button.
  final bool showSettingsButton;

  /// Optional refresh callback — shows a "Refresh"
  /// button alongside the settings button.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: CrispySpacing.md),
            Text(title, style: tt.titleMedium),
            if (description != null) ...[
              const SizedBox(height: CrispySpacing.sm),
              Text(
                description!,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showSettingsButton || onRefresh != null) ...[
              const SizedBox(height: CrispySpacing.lg),
              Wrap(
                spacing: CrispySpacing.sm,
                children: [
                  if (showSettingsButton)
                    FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.settings),
                      icon: const Icon(Icons.settings),
                      label: const Text('Go to Settings'),
                    ),
                  if (onRefresh != null)
                    OutlinedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
