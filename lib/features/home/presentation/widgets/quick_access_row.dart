import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';

// ── Tile & badge layout constants ──────────────────────────────────────────

/// Width and height of each quick-access tile (dp).
const double _kTileSize = 120;

/// Horizontal/vertical inset (dp) from the tile corner to the badge.
const double _kBadgeInset = CrispySpacing.sm;

/// Horizontal padding inside the badge chip.
const double _kBadgePaddingH = CrispySpacing.sm;

/// Vertical padding inside the badge chip.
const double _kBadgePaddingV = CrispySpacing.xxs;

/// Horizontal row of quick-access tiles linking to
/// features that are not primary nav destinations:
/// DVR, Multiview, Cloud Storage, and Search.
class QuickAccessRow extends StatelessWidget {
  /// Creates the quick-access row.
  const QuickAccessRow({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(
              left: CrispySpacing.md,
              right: CrispySpacing.md,
              top: CrispySpacing.xl,
              bottom: CrispySpacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.apps, size: 20, color: cs.primary),
                const SizedBox(width: CrispySpacing.sm),
                Text(
                  'Quick Access',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: _kTileSize,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            children: [
              _QuickAccessTile(
                icon: Icons.grid_view_rounded,
                label: 'Multi\nView',
                badge: 'Beta',
                autofocus: true,
                onTap: () => context.push(AppRoutes.multiview),
              ),
              const SizedBox(width: CrispySpacing.sm),
              _QuickAccessTile(
                icon: Icons.fiber_manual_record_outlined,
                label: 'DVR',
                badge: 'Beta',
                onTap: () => context.go(AppRoutes.dvr),
              ),
              const SizedBox(width: CrispySpacing.sm),
              _QuickAccessTile(
                icon: Icons.cloud_outlined,
                label: 'Cloud\nStorage',
                badge: 'Beta',
                onTap: () => context.push(AppRoutes.cloudBrowser),
              ),
              const SizedBox(width: CrispySpacing.sm),
              _QuickAccessTile(
                icon: Icons.search,
                label: 'Search',
                onTap: () => context.go(AppRoutes.customSearch),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single quick-access tile with icon and label.
class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Optional small badge (e.g. "Beta") shown in the
  /// top-right corner of the tile.
  final String? badge;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FocusWrapper(
      focusStyle: FocusIndicatorStyle.card,
      onSelect: onTap,
      autofocus: autofocus,
      borderRadius: CrispyRadius.tv,
      child: Stack(
        children: [
          Container(
            width: _kTileSize,
            padding: const EdgeInsets.symmetric(
              vertical: CrispySpacing.sm,
              horizontal: CrispySpacing.xs,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: cs.primary),
                const SizedBox(height: CrispySpacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: _kBadgeInset,
              right: _kBadgeInset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kBadgePaddingH,
                  vertical: _kBadgePaddingV,
                ),
                decoration: BoxDecoration(
                  color: cs.tertiary,
                  borderRadius: BorderRadius.circular(CrispyRadius.xs),
                ),
                child: Text(
                  badge!,
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.onTertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
