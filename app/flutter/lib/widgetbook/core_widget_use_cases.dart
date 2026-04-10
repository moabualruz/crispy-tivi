import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../core/theme/theme.dart';
import '../core/widgets/async_filled_button.dart';
import '../core/widgets/content_badge.dart';
import '../core/widgets/crispy_logo.dart';
import '../core/widgets/empty_state_widget.dart';
import '../core/widgets/error_banner.dart';
import '../core/widgets/error_boundary.dart';
import '../core/widgets/error_state_widget.dart';
import '../core/widgets/favorite_star_overlay.dart';
import '../core/widgets/generated_placeholder.dart';
import '../core/widgets/genre_pill_row.dart';
import '../core/widgets/glass_surface.dart';
import '../core/widgets/glassmorphic_sheet.dart';
import '../core/widgets/live_badge.dart';
import '../core/widgets/loading_state_widget.dart';
import '../core/widgets/meta_chip.dart';
import '../core/widgets/nav_arrow.dart';
import '../core/widgets/or_divider_row.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/skeleton_loader.dart';
import '../core/widgets/sparkline.dart';
import '../core/widgets/spoiler_blur.dart';
import '../core/widgets/tv_color_button_legend.dart';
import '../core/widgets/tv_master_detail_layout.dart';
import '../core/widgets/vignette_gradient.dart';
import '../core/widgets/watch_progress_bar.dart';
import 'catalog_surface.dart';

@widgetbook.UseCase(
  name: 'Default and loading',
  type: AsyncFilledButton,
  path: '[Core widgets]/AsyncFilledButton',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Buttons',
)
Widget asyncFilledButtonUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      runSpacing: CrispySpacing.md,
      children: [
        AsyncFilledButton(
          isLoading: false,
          label: 'Add Source',
          onPressed: _noop,
        ),
        AsyncFilledButton(isLoading: true, label: 'Syncing'),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Brand sizes',
  type: CrispyLogo,
  path: '[Core widgets]/CrispyLogo',
  designLink: 'Penpot: CrispyTivi Design System / ASSET - Brand Assets',
)
Widget crispyLogoUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.xl,
      runSpacing: CrispySpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CrispyLogo(size: 32),
        CrispyLogo(size: 56),
        CrispyLogo(size: 88),
        CrispyLogo(size: 56, color: Colors.white),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Live and recording',
  type: LiveBadge,
  path: '[Core widgets]/LiveBadge',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Badges',
)
Widget liveBadgeUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [LiveBadge(), LiveBadge(label: 'REC')],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Content status variants',
  type: ContentStatusBadge,
  path: '[Core widgets]/ContentStatusBadge',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Badges',
)
Widget contentStatusBadgeUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      runSpacing: CrispySpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ContentStatusBadge(badge: ContentBadge.newEpisode),
        ContentStatusBadge(badge: ContentBadge.newSeason),
        ContentStatusBadge(badge: ContentBadge.recording),
        ContentStatusBadge(badge: ContentBadge.expiringSoon),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Metadata variants',
  type: MetaChip,
  path: '[Core widgets]/MetaChip',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Chips',
)
Widget metaChipUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.sm,
      runSpacing: CrispySpacing.sm,
      children: [
        MetaChip(label: '2026'),
        MetaChip(label: '4K'),
        MetaChip(label: 'PG-13'),
        MetaChip(label: 'Drama'),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Selected category',
  type: GenrePillRow,
  path: '[Core widgets]/GenrePillRow',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Chips',
)
Widget genrePillRowUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 520,
      child: GenrePillRow(
        categories: const ['News', 'Sports', 'Movies', 'Kids', 'Music'],
        selectedCategory: 'Sports',
        onCategorySelected: (_) {},
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Icon header',
  type: SectionHeader,
  path: '[Core widgets]/SectionHeader',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Headers',
)
Widget sectionHeaderUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SectionHeader(
      title: 'Sources',
      icon: Icons.playlist_add,
      colorTitle: true,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Default surface',
  type: GlassSurface,
  path: '[Core widgets]/GlassSurface',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Surfaces',
)
Widget glassSurfaceUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SizedBox(
      width: 360,
      child: GlassSurface(
        child: Padding(
          padding: EdgeInsets.all(CrispySpacing.md),
          child: Text(
            'Glass surfaces stay sharp, dark, and token-driven across TV and desktop layouts.',
          ),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Bottom sheet shell',
  type: GlassmorphicSheet,
  path: '[Core widgets]/GlassmorphicSheet',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Core Components',
)
Widget glassmorphicSheetUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 420,
      height: 360,
      child: GlassmorphicSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder:
            (_) => const Padding(
              padding: EdgeInsets.all(CrispySpacing.md),
              child: Text('Sheet content'),
            ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Empty state',
  type: EmptyStateWidget,
  path: '[Core widgets]/EmptyStateWidget',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - State Widgets',
)
Widget emptyStateUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SizedBox(
      width: 280,
      height: 220,
      child: EmptyStateWidget(
        icon: Icons.movie_outlined,
        title: 'No items',
        description: 'Add a playlist source in Settings',
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Loading state',
  type: LoadingStateWidget,
  path: '[Core widgets]/LoadingStateWidget',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - State Widgets',
)
Widget loadingStateUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SizedBox(width: 180, height: 180, child: LoadingStateWidget()),
  );
}

@widgetbook.UseCase(
  name: 'Error state',
  type: ErrorStateWidget,
  path: '[Core widgets]/ErrorStateWidget',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - State Widgets',
)
Widget errorStateUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 280,
      height: 220,
      child: ErrorStateWidget(message: 'Failed to load', onRetry: () {}),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Retry banner',
  type: ErrorBanner,
  path: '[Core widgets]/ErrorBanner',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Core Components',
)
Widget errorBannerUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 520,
      child: ErrorBanner(
        message: 'Failed to refresh channels',
        technicalDetail: 'HTTP 502 while refreshing source sample-news',
        onRetry: () {},
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Full and compact',
  type: ErrorBoundary,
  path: '[Core widgets]/ErrorBoundary',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Core Components',
)
Widget errorBoundaryUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            child: ErrorBoundary(error: 'Source unavailable', onRetry: () {}),
          ),
          const Divider(),
          ErrorBoundary(
            error: 'Short error row',
            compact: true,
            onRetry: () {},
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Favorite states',
  type: FavoriteStarOverlay,
  path: '[Core widgets]/FavoriteStarOverlay',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Media Cards',
)
Widget favoriteStarOverlayUseCase(BuildContext context) {
  return CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.lg,
      runSpacing: CrispySpacing.md,
      children: [
        FavoriteStarOverlay(
          isFavorite: true,
          isHovered: false,
          onToggle: () {},
        ),
        FavoriteStarOverlay(
          isFavorite: false,
          isHovered: true,
          onToggle: () {},
        ),
        FavoriteStarOverlay(
          isFavorite: false,
          isHovered: false,
          onToggle: () {},
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Blurred and revealed',
  type: SpoilerBlur,
  path: '[Core widgets]/SpoilerBlur',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Media Cards',
)
Widget spoilerBlurUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      runSpacing: CrispySpacing.md,
      children: [
        SizedBox(
          width: 160,
          height: 90,
          child: SpoilerBlur(
            isWatched: false,
            child: GeneratedPlaceholder(title: 'Spoiler', icon: Icons.movie),
          ),
        ),
        SizedBox(
          width: 160,
          height: 90,
          child: SpoilerBlur(
            isWatched: true,
            child: GeneratedPlaceholder(title: 'Watched', icon: Icons.movie),
          ),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Skeleton variants',
  type: SkeletonLoader,
  path: '[Core widgets]/SkeletonLoader',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Skeletons',
)
Widget skeletonLoaderUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      runSpacing: CrispySpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SkeletonLine(width: 180),
        SkeletonCard(width: 120, showTitle: true, showSubtitle: true),
        SkeletonAvatar(size: 56),
        SizedBox(width: 280, child: SkeletonRow(itemCount: 3, cardWidth: 72)),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Poster and landscape',
  type: GeneratedPlaceholder,
  path: '[Core widgets]/GeneratedPlaceholder',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Media Cards',
)
Widget generatedPlaceholderUseCase(BuildContext context) {
  return const CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      runSpacing: CrispySpacing.md,
      children: [
        SizedBox(
          width: 120,
          height: 180,
          child: GeneratedPlaceholder(
            title: 'Blue Planet',
            icon: Icons.movie_outlined,
          ),
        ),
        SizedBox(
          width: 160,
          height: 90,
          child: GeneratedPlaceholder(
            title: 'Live Sports',
            icon: Icons.live_tv_outlined,
          ),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Divider label',
  type: OrDividerRow,
  path: '[Core widgets]/OrDividerRow',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Core Components',
)
Widget orDividerRowUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SizedBox(width: 360, child: OrDividerRow()),
  );
}

@widgetbook.UseCase(
  name: 'Threshold line',
  type: Sparkline,
  path: '[Core widgets]/Sparkline',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Player Widgets',
)
Widget sparklineUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SizedBox(
      width: 180,
      height: 72,
      child: Center(
        child: Sparkline(
          width: 150,
          height: 42,
          samples: [12, 24, 30, 68, 72, 54, 22, 18, 64, 88],
          lowThreshold: 25,
          highThreshold: 65,
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Dark and adaptive',
  type: VignetteGradient,
  path: '[Core widgets]/VignetteGradient',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Media Cards',
)
Widget vignetteGradientUseCase(BuildContext context) {
  return CatalogSurface(
    child: Wrap(
      spacing: CrispySpacing.md,
      children: [
        _GradientSample(label: 'Dark', child: const VignetteGradient()),
        _GradientSample(
          label: 'Surface',
          child: const VignetteGradient.surfaceAdaptive(),
        ),
        _GradientSample(
          label: 'Scrim',
          child: const VignetteGradient.surfaceScrim(),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Carousel arrows',
  type: NavArrow,
  path: '[Core widgets]/NavArrow',
  designLink:
      'Penpot: CrispyTivi Design System / PATTERN - Navigation and TV Focus',
)
Widget navArrowUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 260,
      height: 96,
      child: Row(
        children: [
          Expanded(
            child: NavArrow(
              icon: Icons.chevron_left,
              isLeft: true,
              iconSize: 42,
              onTap: () {},
            ),
          ),
          const SizedBox(width: CrispySpacing.md),
          Expanded(
            child: NavArrow(
              icon: Icons.chevron_right,
              isLeft: false,
              iconSize: 42,
              onTap: () {},
            ),
          ),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Detail overlay',
  type: TvMasterDetailLayout,
  path: '[Core widgets]/TvMasterDetailLayout',
  designLink:
      'Penpot: CrispyTivi Design System / PATTERN - Navigation and TV Focus',
)
Widget tvMasterDetailLayoutUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 760,
      height: 320,
      child: TvMasterDetailLayout(
        showDetail: true,
        detailWidthFraction: 0.42,
        onDetailDismissed: () {},
        masterPanel: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: const Center(child: Text('Master panel')),
        ),
        detailPanel: const Center(child: Text('Detail panel')),
      ),
    ),
  );
}

class _GradientSample extends StatelessWidget {
  const _GradientSample({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 180,
            height: 110,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: child,
          ),
          const SizedBox(height: CrispySpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

@widgetbook.UseCase(
  name: 'Progress values',
  type: WatchProgressBar,
  path: '[Core widgets]/WatchProgressBar',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - Media Cards',
)
Widget watchProgressBarUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WatchProgressBar(value: 0.18),
          SizedBox(height: CrispySpacing.md),
          WatchProgressBar(value: 0.52),
          SizedBox(height: CrispySpacing.md),
          WatchProgressBar(value: 0.91),
        ],
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Four-button legend',
  type: TvColorButtonLegend,
  path: '[Core widgets]/TvColorButtonLegend',
  designLink: 'Penpot: CrispyTivi Design System / COMPONENT - TV Controls',
)
Widget tvColorButtonLegendUseCase(BuildContext context) {
  return CatalogSurface(
    child: SizedBox(
      width: 560,
      child: TvColorButtonLegend(
        colorButtonMap: {
          TvColorButton.red: ColorButtonAction(
            label: 'Clear',
            icon: Icons.close,
            onPressed: () {},
          ),
          TvColorButton.green: ColorButtonAction(
            label: 'Search',
            icon: Icons.search,
            onPressed: () {},
          ),
          TvColorButton.yellow: ColorButtonAction(
            label: 'Sort',
            icon: Icons.sort,
            onPressed: () {},
          ),
          TvColorButton.blue: ColorButtonAction(
            label: 'My List',
            icon: Icons.playlist_add_check,
            onPressed: () {},
          ),
        },
      ),
    ),
  );
}

void _noop() {}
