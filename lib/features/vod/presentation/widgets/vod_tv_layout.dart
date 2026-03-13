import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../domain/entities/vod_item.dart';
import 'vod_movies_tab.dart';

/// TV master-detail layout for the VOD browser screen.
///
/// Master panel: VOD movies tab content (categories + grid).
/// Detail panel: welcome/instruction message when nothing is selected.
class VodTvLayout extends StatelessWidget {
  /// Creates the VOD TV layout.
  const VodTvLayout({
    required this.movieCategories,
    required this.newReleases,
    super.key,
  });

  /// Movie category list for the filter dropdown.
  final List<String> movieCategories;

  /// New release items for the top section.
  final List<VodItem> newReleases;

  @override
  Widget build(BuildContext context) {
    return TvMasterDetailLayout(
      masterPanel: FocusTraversalGroup(
        child: VodMoviesTab(
          movieCategories: movieCategories,
          newReleases: newReleases,
        ),
      ),
      detailPanel: const _VodDetailPanel(),
    );
  }
}

class _VodDetailPanel extends StatelessWidget {
  const _VodDetailPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: CrispySpacing.md),
          Text(
            'Select a title',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Choose a movie to see details',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
