import 'package:flutter/material.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/domain/entities/media_type.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../domain/constants/search_source_key.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/smart_image.dart';

// ── Source bar constants ──────────────────────────────────────────────────────

/// Width of the color-coded source indicator bar on the left edge of a card.
const double _kSourceBarWidth = 3.0;

// ── Image dimension constants ─────────────────────────────────────────────────

/// Width of the thumbnail for channel-type results.
const double _kChannelImageWidth = 56.0;

/// Height of the thumbnail for channel-type results.
const double _kChannelImageHeight = 56.0;

/// Width of the thumbnail for non-channel (movie/series/episode) results.
const double _kVodImageWidth = 80.0;

/// Height of the thumbnail for non-channel results.
const double _kVodImageHeight = 120.0;

/// Size of the inline play button (filled circle diameter).
const double _kPlayButtonSize = 36.0;

/// Enhanced search result card with rich metadata display.
///
/// Shows poster/logo, title, metadata row (year, rating,
/// duration, category), description preview, source badge,
/// a visible play button (FE-SR-05), and a contextual popup
/// menu (Favorite, Details).
class EnhancedSearchResultCard extends StatelessWidget {
  const EnhancedSearchResultCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onFavorite,
    this.onDetails,
  });

  final MediaItem item;
  final VoidCallback onTap;

  /// Called when "Add to Favorites" is tapped. Null hides
  /// the option.
  final VoidCallback? onFavorite;

  /// Called when "View Details" is tapped. Null hides the
  /// option.
  final VoidCallback? onDetails;

  // TODO(l10n): S-025 — source badge labels below are product/service names
  // (IPTV, VOD, EPG, Jellyfin, Emby, Plex). Add l10n keys if translation is
  // required; product acronyms are often kept untranslated by convention.
  String? get _source {
    final source = item.metadata['source'];
    if (source == null) return null;
    switch (source) {
      case SearchSourceKey.iptv:
        return 'IPTV';
      case SearchSourceKey.iptvVod:
        return 'VOD';
      case SearchSourceKey.iptvEpg:
        return 'EPG';
      case SearchSourceKey.jellyfin:
        return 'Jellyfin';
      case SearchSourceKey.emby:
        return 'Emby';
      case SearchSourceKey.plex:
        return 'Plex';
      default:
        return source.toString().toUpperCase();
    }
  }

  /// FE-SR-10: Returns the color for the left-edge source bar based
  /// on the media type / source combination.
  Color _sourceBarColor(ColorScheme cs) {
    final source = item.metadata['source'] as String?;
    // EPG programs — use outline to distinguish from playable content.
    if (source == SearchSourceKey.iptvEpg) return cs.outline;
    // Live TV channels.
    if (item.type == MediaType.channel) return cs.primary;
    // VOD series.
    if (item.type == MediaType.series ||
        item.type == MediaType.season ||
        item.type == MediaType.episode) {
      return cs.secondary;
    }
    // Movies (and other playable items).
    return cs.tertiary;
  }

  String? get _duration =>
      item.durationMs != null && item.durationMs! > 0
          ? DurationFormatter.humanShortMs(item.durationMs)
          : null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine image aspect ratio based on type.
    final isChannel = item.type == MediaType.channel;
    final imageWidth = isChannel ? _kChannelImageWidth : _kVodImageWidth;
    final imageHeight = isChannel ? _kChannelImageHeight : _kVodImageHeight;

    // FE-SR-10: color-coded source bar on the left edge.
    final barColor = _sourceBarColor(colorScheme);

    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.md,
      scaleFactor: CrispyAnimation.hoverScale,
      padding: EdgeInsets.zero,
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        clipBehavior: Clip.antiAlias,
        // Outer row: [colored bar | card content]
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FE-SR-10: thin color-coded source indicator bar.
            Container(width: _kSourceBarWidth, color: barColor),

            // Main card content (poster + text + actions).
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(CrispySpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster / Logo
                    SizedBox(
                      width: imageWidth,
                      height: imageHeight,
                      child: SmartImage(
                        title: item.name,
                        imageUrl: item.logoUrl,
                        fit: isChannel ? BoxFit.contain : BoxFit.cover,
                        memCacheWidth: (imageWidth * 2).toInt(),
                        memCacheHeight: (imageHeight * 2).toInt(),
                      ),
                    ),

                    const SizedBox(width: CrispySpacing.md),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row with source badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_source != null) ...[
                                const SizedBox(width: CrispySpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: CrispySpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      CrispyRadius.none,
                                    ),
                                  ),
                                  child: Text(
                                    _source!,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: CrispySpacing.xs),

                          // Metadata row
                          _MetadataRow(
                            year: item.year,
                            rating: item.rating,
                            duration: _duration,
                            category: item.metadata['category'] as String?,
                          ),

                          // Description preview
                          if (item.overview != null &&
                              item.overview!.isNotEmpty) ...[
                            const SizedBox(height: CrispySpacing.xs),
                            Text(
                              item.overview!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // FE-SR-05: Trailing action column — play button
                    // always visible, overflow menu when applicable.
                    // Wrapped in a Column so both buttons stay vertically
                    // centered relative to each other.
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PlayButton(onPlay: onTap),
                        if (onFavorite != null || onDetails != null)
                          _ActionsMenu(
                            onFavorite: onFavorite,
                            onDetails: onDetails,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({this.year, this.rating, this.duration, this.category});

  final int? year;
  final String? rating;
  final String? duration;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final items = <String>[];
    if (year != null) items.add(year.toString());
    if (rating != null && rating!.isNotEmpty) items.add(rating!);
    if (duration != null) items.add(duration!);
    if (category != null && category!.isNotEmpty) items.add(category!);

    if (items.isEmpty) return const SizedBox.shrink();

    return Text(
      items.join(' • '),
      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── FE-SR-05: Inline play button ─────────────────────────────────────────────

/// A filled circular play button displayed on every search result card.
///
/// Initiates playback immediately without navigating to a detail page.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: CrispySpacing.xs),
      child: Tooltip(
        message: context.l10n.commonPlay,
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(CrispyRadius.full),
          child: Container(
            width: _kPlayButtonSize,
            height: _kPlayButtonSize,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow,
              color: colorScheme.onPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Contextual popup menu ─────────────────────────────────────────────────────

/// Contextual popup menu for secondary search result actions
/// (Favorite, Details). Play is handled by [_PlayButton].
class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({this.onFavorite, this.onDetails});

  final VoidCallback? onFavorite;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<_Action>(
      icon: Icon(
        Icons.more_vert,
        color: colorScheme.onSurfaceVariant,
        size: 20,
      ),
      tooltip: context.l10n.playerMoreOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 0),
      onSelected: (action) {
        switch (action) {
          case _Action.favorite:
            onFavorite?.call();
          case _Action.details:
            onDetails?.call();
        }
      },
      itemBuilder:
          (menuContext) => [
            if (onFavorite != null)
              PopupMenuItem(
                value: _Action.favorite,
                child: ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: Text(menuContext.l10n.contextMenuAddFavorite),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (onDetails != null)
              PopupMenuItem(
                value: _Action.details,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(menuContext.l10n.contextMenuViewDetails),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
    );
  }
}

enum _Action { favorite, details }
