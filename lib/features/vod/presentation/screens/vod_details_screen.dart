import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/cinematic_hero_banner.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/vod_item.dart';
import '../../domain/utils/vod_utils.dart';
import '../providers/vod_providers.dart';
import '../../../../config/settings_notifier.dart';
import '../../../../core/testing/test_keys.dart';
import '../widgets/cast_scroll_row.dart';
import '../widgets/episode_playback_helper.dart' show showResumeDialog;
import '../widgets/vod_detail_body.dart';
import '../widgets/vod_detail_metadata.dart';
import '../widgets/vod_source_picker.dart';

/// Formats a runtime duration in minutes into a human-readable string.
///
/// Examples:
/// - 45 → "45m"
/// - 90 → "1h 30m"
/// - 120 → "2h"
String formatRuntime(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}

/// Cinematic details screen for VOD (Movies).
/// Netflix-style layout per .ai/docs/plans/netflix_ui_reference.md.
///
/// Features:
/// - Immersive Hero Banner (500px, multi-stop gradient).
/// - Netflix-style metadata badges (year, rating,
///   duration).
/// - Quality badges (HD, 4K) from extension field.
/// - Primary Actions (Play, My List, Rate).
/// - Expandable Synopsis.
/// - Two-column layout on desktop (>= 1280px).
/// - "More Like This" carousel with larger cards.
class VodDetailsScreen extends ConsumerStatefulWidget {
  const VodDetailsScreen({required this.item, this.heroTag, super.key});

  final VodItem item;
  final String? heroTag;

  @override
  ConsumerState<VodDetailsScreen> createState() => _VodDetailsScreenState();
}

class _VodDetailsScreenState extends ConsumerState<VodDetailsScreen> {
  // FE-VODS-06-DETAILS: Track overridden stream URL from source picker.
  // Defaults to the item's own URL; updated when user picks a different source.
  String? _overrideStreamUrl;

  /// True while the play action is resolving history / starting playback.
  /// Prevents double-tap race conditions.
  bool _isPlayLoading = false;

  /// Builds the multi-source list for this item.
  ///
  /// Prepends the item itself as the primary source, then appends any
  /// [alternatives] returned by [vodAlternativeSourcesProvider] so that
  /// [VodSourcePicker] reveals the section when cross-source duplicates exist.
  List<VodSource> _buildSources(
    VodItem item,
    String? sourceName,
    List<VodSource> alternatives,
  ) {
    return [
      VodSource.fromVodItem(item, sourceName: sourceName),
      ...alternatives,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final textTheme = Theme.of(context).textTheme;
    // Find the up-to-date item from provider,
    // fallback to passed item
    final liveItem = ref.watch(
      vodProvider.select(
        (s) => s.items.firstWhere(
          (element) => element.id == widget.item.id,
          orElse: () => widget.item,
        ),
      ),
    );

    final recommendations = ref.watch(vodSimilarItemsProvider(liveItem.id));
    final quality = resolveVodQuality(item);
    final isWatched =
        ref.watch(isWatchedProvider(item.streamUrl)).asData?.value ?? false;

    final settings = ref.watch(settingsNotifierProvider.select((s) => s.value));
    final sourceName =
        settings?.sources
            .where((s) => s.id == liveItem.sourceId)
            .firstOrNull
            ?.name;

    final alternatives =
        ref.watch(vodAlternativeSourcesProvider(liveItem)).asData?.value ?? [];

    return Semantics(
      label: item.name,
      child: Scaffold(
        key: TestKeys.vodDetailsScreen,
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: FocusTraversalGroup(
          child: CustomScrollView(
            slivers: [
              // ── Hero Banner ──
              CinematicHeroBanner(
                heroTag: widget.heroTag ?? item.id,
                expandedHeight: 500,
                image: SmartImage(
                  itemId: item.id,
                  title: item.name,
                  imageUrl: item.backdropUrl ?? item.posterUrl,
                  imageKind: 'backdrop',
                  icon: Icons.movie,
                  placeholderAspectRatio: 16 / 9,
                  memCacheWidth: 800,
                ),
                titleColumn: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      item.name,
                      style: textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: CrispyColors.vignetteEnd,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CrispySpacing.sm),

                    // Metadata Row + Quality
                    Row(
                      children: [
                        if (item.year != null) MetaChip(label: '${item.year}'),
                        // FE-VD-11: Content advisory chip — rating field
                        // may hold numeric score ("7.5") or content
                        // rating ("PG-13", "TV-MA"). Displayed with
                        // outline border to visually distinguish it.
                        if (item.rating != null)
                          _RatingChip(rating: item.rating!),
                        // FE-VD-03: Runtime formatted as "Xh Ym"
                        if (item.duration != null)
                          MetaChip(label: formatRuntime(item.duration!)),
                        if (item.category != null)
                          MetaChip(label: item.category!),
                        if (quality != null) QualityBadge(label: quality),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Actions & Synopsis ──
              SliverToBoxAdapter(
                child: BodyContent(
                  item: item,
                  liveItem: liveItem,
                  textTheme: textTheme,
                  onPlay: _isPlayLoading ? null : () => _play(context),
                  onToggleFavorite: () => _toggleFavorite(liveItem.id),
                  isWatched: isWatched,
                  onMarkWatched: () => _toggleWatched(context),
                  onShare: () => _copyToClipboard(context),
                ),
              ),

              // ── Cast & Crew (FE-VODS-01) ──
              SliverToBoxAdapter(
                child: CastScrollRow(castNames: liveItem.cast),
              ),

              // ── Sources (FE-VODS-06-DETAILS) ──
              SliverToBoxAdapter(
                child: VodSourcePicker(
                  itemId: liveItem.id,
                  sources: _buildSources(liveItem, sourceName, alternatives),
                  onSourceSelected: (source) {
                    setState(() => _overrideStreamUrl = source.streamUrl);
                  },
                ),
              ),

              // ── More Like This ──
              if (recommendations.isNotEmpty)
                SliverToBoxAdapter(
                  child: MovieRecommendationsSection(
                    recommendations: recommendations,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context) async {
    if (_isPlayLoading) return;
    setState(() => _isPlayLoading = true);
    try {
      await _doPlay(context);
    } finally {
      if (mounted) setState(() => _isPlayLoading = false);
    }
  }

  Future<void> _doPlay(BuildContext context) async {
    final item = widget.item;
    // FE-VODS-06-DETAILS: use the source-picker override URL when set.
    final resolvedUrl = _overrideStreamUrl ?? item.streamUrl;
    final id = WatchHistoryService.deriveId(resolvedUrl);
    final history = await ref.read(watchHistoryServiceProvider).getById(id);

    if (history != null && history.positionMs > 0 && history.durationMs > 0) {
      final progress = history.progress.clamp(0.0, 1.0);
      if (progress < kCompletionThreshold && context.mounted) {
        final formatted = ref
            .read(crispyBackendProvider)
            .formatPlaybackDuration(history.positionMs, history.durationMs);
        final resume = await showResumeDialog(context, formatted);
        if (!context.mounted) return;

        ref
            .read(playbackSessionProvider.notifier)
            .startPlayback(
              streamUrl: resolvedUrl,
              isLive: false,
              channelName: item.name,
              channelLogoUrl: item.posterUrl,
              posterUrl: item.posterUrl,
              mediaType: item.type.mediaType,
              startPosition:
                  resume ? Duration(milliseconds: history.positionMs) : null,
              sourceId: widget.item.sourceId,
            );
        return;
      }
    }

    // No history or completed — start from beginning
    ref
        .read(playbackSessionProvider.notifier)
        .startPlayback(
          streamUrl: resolvedUrl,
          isLive: false,
          channelName: item.name,
          channelLogoUrl: item.posterUrl,
          posterUrl: item.posterUrl,
          mediaType: item.type == VodType.movie ? 'movie' : 'episode',
          sourceId: widget.item.sourceId,
        );
  }

  void _toggleFavorite(String itemId) {
    ref.read(vodProvider.notifier).toggleFavorite(itemId);
  }

  /// Toggles the "watched" state for this VOD item.
  ///
  /// If already watched, deletes the history entry (unmarks).
  /// If not watched, writes a completed entry (positionMs = durationMs
  /// with a 1 ms sentinel when duration is unknown).
  Future<void> _toggleWatched(BuildContext context) async {
    final item = widget.item;
    final id = WatchHistoryService.deriveId(item.streamUrl);
    final service = ref.read(watchHistoryServiceProvider);

    final existing = await service.getById(id);
    final alreadyWatched = existing?.isNearlyComplete ?? false;

    if (alreadyWatched) {
      await service.delete(id);
    } else {
      // Use actual duration when known; sentinel 1/1 = 100% otherwise.
      final durationMs =
          existing?.durationMs != null && existing!.durationMs > 0
              ? existing.durationMs
              : 1;
      final entry = WatchHistoryEntry(
        id: id,
        mediaType: item.type.mediaType,
        name: item.name,
        streamUrl: item.streamUrl,
        posterUrl: item.posterUrl,
        positionMs: durationMs,
        durationMs: durationMs,
        lastWatched: DateTime.now(),
      );
      await ref.read(cacheServiceProvider).saveWatchHistory(entry);
    }

    // Invalidate so isWatchedProvider re-evaluates.
    ref.invalidate(isWatchedProvider(item.streamUrl));

    if (context.mounted) {
      final msg = alreadyWatched ? 'Marked as unwatched' : 'Marked as watched';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// Shares the deep link for this VOD item.
  ///
  /// Deep link format: `crispytivi://vods/details?id=<itemId>`
  ///
  /// - Android / iOS: uses [SharePlus.share] to open the OS share sheet.
  /// - TV / desktop / web: falls back to clipboard copy with a snackbar.
  Future<void> _copyToClipboard(BuildContext context) async {
    final item = widget.item;
    final deepLink = 'crispytivi://vods/details?id=${item.id}';
    final shareText =
        item.year != null
            ? '${item.name} (${item.year})\n$deepLink'
            : '${item.name}\n$deepLink';

    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile) {
      // Use OS share sheet on mobile.
      await SharePlus.instance.share(ShareParams(text: shareText));
    } else {
      // Copy deep link to clipboard on TV / desktop / web.
      await Clipboard.setData(ClipboardData(text: deepLink));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Link copied to clipboard')),
          );
      }
    }
  }
}

/// FE-VD-11: Content advisory / age rating chip.
///
/// Renders the [VodItem.rating] field with an outlined border using
/// [ColorScheme.outline] to visually distinguish it from plain
/// metadata chips. Handles both numeric scores ("7.5") and content
/// ratings ("PG-13", "TV-MA", "R").
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        rating,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
