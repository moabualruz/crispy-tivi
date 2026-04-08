import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/nav_arrow.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';
import 'vod_layout_helpers.dart';
import 'vod_poster_card.dart';

/// Badge type shown on recently-added cards.
enum _NewBadgeKind {
  /// Item was recently released (release year is current or previous year).
  newRelease,

  /// Item was recently added to the IPTV library (addedAt within 30 days).
  newToLibrary,
}

/// Determines which badge, if any, to show for [item].
///
/// Priority: "New Release" wins over "New to Library" when both apply.
_NewBadgeKind? _badgeKind(VodItem item) {
  final now = DateTime.now();
  final recentYear = now.year - 1;

  final isNewRelease = item.year != null && item.year! >= recentYear;
  final isNewToLibrary =
      item.addedAt != null && now.difference(item.addedAt!).inDays <= 30;

  if (isNewRelease) return _NewBadgeKind.newRelease;
  if (isNewToLibrary) return _NewBadgeKind.newToLibrary;

  // Fallback: if addedAt is null but item is in the recently-added list,
  // still show a "New to Library" badge (provider already filtered it).
  return _NewBadgeKind.newToLibrary;
}

/// Horizontal carousel showing recently added VOD items.
///
/// Each card shows a badge distinguishing:
/// - "New Release" — item's release year is current or previous year
///   (shown in [ColorScheme.tertiary]).
/// - "New to Library" — item was added to the source within 30 days
///   (shown in [ColorScheme.secondary]).
class RecentlyAddedSection extends ConsumerStatefulWidget {
  const RecentlyAddedSection({
    super.key,
    this.onItemTap,
    this.showMoviesOnly = false,
    this.showSeriesOnly = false,
  });

  /// Called when a VOD item is tapped.
  final void Function(VodItem item)? onItemTap;

  /// Show only recently added movies.
  final bool showMoviesOnly;

  /// Show only recently added series.
  final bool showSeriesOnly;

  @override
  ConsumerState<RecentlyAddedSection> createState() =>
      _RecentlyAddedSectionState();
}

class _RecentlyAddedSectionState extends ConsumerState<RecentlyAddedSection> {
  final _scrollController = ScrollController();
  bool _isHovered = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<VodItem> items;

    if (widget.showMoviesOnly) {
      items = ref.watch(recentlyAddedMoviesProvider);
    } else if (widget.showSeriesOnly) {
      items = ref.watch(recentlyAddedSeriesProvider);
    } else {
      items = ref.watch(recentlyAddedAllProvider);
    }

    if (items.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(
            left: CrispySpacing.md,
            right: CrispySpacing.md,
            top: CrispySpacing.xl,
            bottom: CrispySpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.new_releases, size: 20, color: colorScheme.primary),
              const SizedBox(width: CrispySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary,
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  'NEW',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                'Recently Added',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} items',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Horizontal carousel
        Builder(
          builder: (context) {
            final w = MediaQuery.sizeOf(context).width;
            final sectionH = vodSectionHeight(w);
            return MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: SizedBox(
                height: sectionH,
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CrispySpacing.md,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right:
                                index < items.length - 1 ? CrispySpacing.xs : 0,
                          ),
                          child: _RecentlyAddedCard(
                            item: item,
                            onTap: () => widget.onItemTap?.call(item),
                          ),
                        );
                      },
                    ),
                    if (_isHovered)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 36,
                        child: NavArrow(
                          icon: Icons.chevron_left,
                          onTap: () => _scrollBy(-200),
                          isLeft: true,
                          iconSize: 20,
                        ),
                      ),
                    if (_isHovered)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 36,
                        child: NavArrow(
                          icon: Icons.chevron_right,
                          onTap: () => _scrollBy(200),
                          isLeft: false,
                          iconSize: 20,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// VOD poster card with animated badge overlay.
///
/// The badge label and color reflect whether the item is a
/// "New Release" (tertiary) or "New to Library" (secondary).
class _RecentlyAddedCard extends StatefulWidget {
  const _RecentlyAddedCard({required this.item, required this.onTap});

  final VodItem item;
  final VoidCallback onTap;

  @override
  State<_RecentlyAddedCard> createState() => _RecentlyAddedCardState();
}

class _RecentlyAddedCardState extends State<_RecentlyAddedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: CrispyAnimation.slow,
    );

    // Scale animation with bounce effect
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: CrispyAnimation.bounceCurve,
      ),
    );

    // Opacity animation
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: const Interval(0.0, 0.5, curve: CrispyAnimation.scrollCurve),
      ),
    );

    // Start animation after frame is built with slight delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(CrispyAnimation.fast, () {
        if (mounted) _badgeController.forward();
      });
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final w = MediaQuery.sizeOf(context).width;
    final cardW = vodPosterCardWidth(w);
    final kind = _badgeKind(widget.item);

    final (badgeLabel, badgeColor, badgeOnColor) = switch (kind) {
      _NewBadgeKind.newRelease => (
        'NEW RELEASE',
        colorScheme.tertiary,
        colorScheme.onTertiary,
      ),
      _NewBadgeKind.newToLibrary => (
        'NEW TO LIBRARY',
        colorScheme.secondary,
        colorScheme.onSecondary,
      ),
      null => ('NEW', colorScheme.tertiary, colorScheme.onTertiary),
    };

    return Stack(
      children: [
        // Poster card
        SizedBox(
          width: cardW,
          child: VodPosterCard(item: widget.item, onTap: widget.onTap),
        ),

        // Animated badge — "New Release" or "New to Library"
        Positioned(
          top: 8,
          left: 8,
          child: AnimatedBuilder(
            animation: _badgeController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(opacity: _opacityAnimation.value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.zero,
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeLabel,
                style:
                    textTheme.labelSmall?.copyWith(
                      color: badgeOnColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ) ??
                    TextStyle(
                      color: badgeOnColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
