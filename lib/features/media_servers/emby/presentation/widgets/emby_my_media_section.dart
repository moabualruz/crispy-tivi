import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/widgets/responsive_layout.dart';

/// "My Media" section for the Emby home screen (FE-EB-07).
///
/// Displays library-type tiles (Movies, TV Shows, Music, etc.) in a
/// responsive grid. Each tile shows an icon, library name, and item
/// count. Tapping navigates to the library browse screen.
///
/// [libraries] is the list of root Emby user-views (folders) returned
/// by [embyLibrariesProvider]. The count shown is derived from
/// [MediaItem.metadata]['ChildCount'] when available.
class EmbyMyMediaSection extends StatelessWidget {
  const EmbyMyMediaSection({super.key, required this.libraries});

  /// Root Emby library folders to display as tiles.
  final List<MediaItem> libraries;

  @override
  Widget build(BuildContext context) {
    if (libraries.isEmpty) return const SizedBox.shrink();

    final crossAxisCount = switch (context.layoutClass) {
      LayoutClass.compact => 2,
      LayoutClass.medium => 3,
      _ => 4,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CrispySpacing.md,
            CrispySpacing.lg,
            CrispySpacing.md,
            CrispySpacing.sm,
          ),
          child: Text(
            'My Media',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: CrispySpacing.sm,
            crossAxisSpacing: CrispySpacing.sm,
            childAspectRatio: 1.6,
          ),
          itemCount: libraries.length,
          itemBuilder: (context, index) {
            return _LibraryTypeTile(library: libraries[index]);
          },
        ),
      ],
    );
  }
}

// ── Library type tile ─────────────────────────────────────────────────────

class _LibraryTypeTile extends StatelessWidget {
  const _LibraryTypeTile({required this.library});

  final MediaItem library;

  /// Returns an icon appropriate for the library type.
  ///
  /// Emby stores the collection type in [MediaItem.metadata]['CollectionType'].
  /// Falls back to [MediaType]-based icons.
  static IconData _iconFor(MediaItem lib) {
    final collectionType = lib.metadata['CollectionType'] as String? ?? '';

    return switch (collectionType.toLowerCase()) {
      'movies' => Icons.movie_outlined,
      'tvshows' => Icons.tv_outlined,
      'music' => Icons.music_note_outlined,
      'musicvideos' => Icons.music_video_outlined,
      'books' => Icons.menu_book_outlined,
      'photos' => Icons.photo_library_outlined,
      'homevideos' => Icons.video_library_outlined,
      'livetv' => Icons.live_tv_outlined,
      _ => switch (lib.type) {
        MediaType.movie => Icons.movie_outlined,
        MediaType.series => Icons.tv_outlined,
        MediaType.channel => Icons.live_tv_outlined,
        _ => Icons.folder_outlined,
      },
    };
  }

  /// Extracts the child count from metadata if available.
  int? get _childCount {
    final raw = library.metadata['ChildCount'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = _childCount;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: const BorderRadius.all(Radius.circular(CrispyRadius.tv)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(CrispyRadius.tv)),
        onTap: () {
          context.push(
            '/emby/library/${library.id}'
            '?title=${Uri.encodeComponent(library.name)}',
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(CrispySpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CrispyRadius.tv),
                  ),
                ),
                child: Icon(
                  _iconFor(library),
                  color: cs.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: CrispySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      library.name,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (count != null) ...[
                      const SizedBox(height: CrispySpacing.xxs),
                      Text(
                        '$count ${count == 1 ? 'item' : 'items'}',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
