import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/nav_arrow.dart';
import '../providers/channel_providers.dart';

/// Horizontal filter-chip row shown above the channel list.
///
/// Displays "All" plus one chip per unique group derived from
/// the current channel list. Tapping a chip calls
/// [channelListProvider.notifier.selectGroup] so the existing
/// group-filter pipeline handles exclusion.
///
/// On hover (desktop), left/right scroll arrows are revealed so
/// the row is fully navigable without a horizontal scrollbar.
///
/// Spec: FE-TV-09.
class ChannelGenreChipsSliver extends ConsumerStatefulWidget {
  const ChannelGenreChipsSliver({super.key});

  @override
  ConsumerState<ChannelGenreChipsSliver> createState() =>
      _ChannelGenreChipsSliverState();
}

class _ChannelGenreChipsSliverState
    extends ConsumerState<ChannelGenreChipsSliver> {
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
    final groups = ref.watch(channelListProvider.select((s) => s.groups));
    final selected = ref.watch(
      channelListProvider.select((s) => s.effectiveGroup),
    );
    final hasFavorites = ref.watch(
      channelListProvider.select((s) => s.favoriteCount > 0),
    );

    // Build chip labels: genres only (exclude favorites pseudo-group,
    // that is handled by the groups sidebar / group row).
    final genres = groups.where((g) => g.isNotEmpty).toList();

    // Nothing to show if there is only one genre or none at all.
    if (genres.length <= 1) return const SliverToBoxAdapter(child: SizedBox());

    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(channelListProvider.notifier);

    // "All" chip is selected when selectedGroup is null or Favorites.
    final allSelected =
        selected == null || selected == ChannelListState.favoritesGroup;
    // Favorites chip selection (kept separate from genre chips).
    final favSelected =
        hasFavorites && selected == ChannelListState.favoritesGroup;

    return SliverToBoxAdapter(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: SizedBox(
          height: 44,
          child: Stack(
            children: [
              ListView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.xs,
                ),
                children: [
                  // ── All ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(right: CrispySpacing.xs),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: allSelected && !favSelected,
                      onSelected: (_) => notifier.selectGroup(null),
                      selectedColor: colorScheme.primaryContainer,
                      checkmarkColor: colorScheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        color:
                            (allSelected && !favSelected)
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // ── Favorites ────────────────────────────────────
                  if (hasFavorites)
                    Padding(
                      padding: const EdgeInsets.only(right: CrispySpacing.xs),
                      child: FilterChip(
                        label: const Text('Favorites'),
                        selected: favSelected,
                        onSelected:
                            (_) => notifier.selectGroup(
                              ChannelListState.favoritesGroup,
                            ),
                        selectedColor: colorScheme.primaryContainer,
                        checkmarkColor: colorScheme.onPrimaryContainer,
                        avatar: const Icon(Icons.star, size: 16),
                        labelStyle: TextStyle(
                          color:
                              favSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  // ── Genre chips ──────────────────────────────────
                  for (final genre in genres)
                    Padding(
                      padding: const EdgeInsets.only(right: CrispySpacing.xs),
                      child: FilterChip(
                        label: Text(genre),
                        selected: selected == genre,
                        onSelected: (_) => notifier.selectGroup(genre),
                        selectedColor: colorScheme.primaryContainer,
                        checkmarkColor: colorScheme.onPrimaryContainer,
                        labelStyle: TextStyle(
                          color:
                              selected == genre
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
              // ── Hover-reveal scroll arrows ─────────────────────
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
      ),
    );
  }
}
