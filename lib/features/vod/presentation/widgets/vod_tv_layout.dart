import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../domain/entities/vod_item.dart';
import '../providers/vod_providers.dart';
import 'vod_movies_tab.dart';

/// Inherited widget so any descendant (VodRow, VodMoviesGrid, etc.) can
/// intercept item selection for the TV detail slide-over instead of
/// navigating directly to the detail screen.
class VodTvSelectionScope extends InheritedWidget {
  const VodTvSelectionScope({
    required this.onItemSelected,
    required super.child,
    super.key,
  });

  final ValueChanged<VodItem> onItemSelected;

  /// Returns the scope if present (TV layout), or null (phone/tablet).
  static VodTvSelectionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VodTvSelectionScope>();
  }

  @override
  bool updateShouldNotify(VodTvSelectionScope oldWidget) =>
      onItemSelected != oldWidget.onItemSelected;
}

/// TV layout for the VOD browser screen.
///
/// Master: full-width movies tab. On item select (Enter/OK/tap),
/// a detail pane slides over from the right with poster, info,
/// and a Play button that gets autofocus for D-pad.
class VodTvLayout extends StatefulWidget {
  const VodTvLayout({
    required this.movieCategories,
    required this.newReleases,
    super.key,
  });

  final List<String> movieCategories;
  final List<VodItem> newReleases;

  @override
  State<VodTvLayout> createState() => _VodTvLayoutState();
}

class _VodTvLayoutState extends State<VodTvLayout> {
  VodItem? _selectedItem;

  void _onItemSelected(VodItem item) {
    setState(() => _selectedItem = item);
  }

  void _dismiss() {
    setState(() => _selectedItem = null);
  }

  void _navigateToDetail() {
    if (_selectedItem == null) return;
    final item = _selectedItem!;
    _dismiss();
    context.push(
      AppRoutes.vodDetails,
      extra: {'item': item, 'heroTag': '${item.id}_tv'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return VodTvSelectionScope(
      onItemSelected: _onItemSelected,
      child: TvMasterDetailLayout(
        showDetail: _selectedItem != null,
        onDetailDismissed: _dismiss,
        masterPanel: FocusTraversalGroup(
          child: VodMoviesTab(
            movieCategories: widget.movieCategories,
            newReleases: widget.newReleases,
          ),
        ),
        detailPanel: _VodDetailPanel(
          item: _selectedItem,
          onPlay: _navigateToDetail,
        ),
      ),
    );
  }
}

class _VodDetailPanel extends ConsumerWidget {
  const _VodDetailPanel({required this.item, required this.onPlay});

  final VodItem? item;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item == null) return const SizedBox.shrink();

    // Trigger on-demand metadata fetch for Xtream items
    // that are missing detailed info (description, cast, etc.).
    final detailAsync = ref.watch(vodDetailProvider(item!));
    final displayItem = detailAsync.asData?.value ?? item!;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SmartImage(
                    itemId: displayItem.id,
                    title: displayItem.name,
                    imageUrl: displayItem.posterUrl,
                    imageKind: 'poster',
                    icon: Icons.movie_outlined,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.lg),

          // Title
          Text(
            displayItem.name,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: CrispySpacing.sm),

          // Metadata
          Wrap(
            spacing: CrispySpacing.sm,
            children: [
              if (displayItem.year != null)
                Text(
                  '${displayItem.year}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (displayItem.category != null)
                Text(
                  displayItem.category!,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (displayItem.rating != null && displayItem.rating!.isNotEmpty)
                Text(
                  '\u2605 ${displayItem.rating}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (displayItem.duration != null && displayItem.duration! > 0)
                Text(
                  '${displayItem.duration} min',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: CrispySpacing.md),

          // Loading indicator while metadata is being fetched
          if (detailAsync.isLoading &&
              (displayItem.description == null ||
                  displayItem.description!.isEmpty))
            const Padding(
              padding: EdgeInsets.only(bottom: CrispySpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),

          // Synopsis
          if (displayItem.description != null &&
              displayItem.description!.isNotEmpty) ...[
            Text(
              displayItem.description!,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CrispySpacing.md),
          ],

          // Director
          if (displayItem.director != null &&
              displayItem.director!.isNotEmpty) ...[
            Text(
              'Director: ${displayItem.director}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: CrispySpacing.xs),
          ],

          // Cast (first 3)
          if (displayItem.cast != null && displayItem.cast!.isNotEmpty) ...[
            Text(
              'Cast: ${displayItem.cast!.take(3).join(', ')}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CrispySpacing.md),
          ],

          // View Details button — autofocus for D-pad/keyboard
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              autofocus: true,
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('To Movie'),
            ),
          ),
        ],
      ),
    );
  }
}
