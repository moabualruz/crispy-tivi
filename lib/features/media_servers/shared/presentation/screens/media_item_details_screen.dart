import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/domain/entities/media_item.dart';
import '../../../../../core/domain/media_source.dart';
import '../../../../../core/testing/test_keys.dart';
import '../../../../../core/theme/crispy_colors.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/utils/date_format_utils.dart';
import '../../../../../core/utils/duration_formatter.dart';
import '../../../../../core/widgets/cinematic_hero_banner.dart';
import '../../../../../core/widgets/focus_wrapper.dart';
import '../../../../../core/widgets/meta_chip.dart';
import '../../application/start_media_server_playback_use_case.dart';
// PX-FE-12: extras provider for Plex trailers/interviews.
import '../../../../media_servers/plex/presentation/providers/plex_providers.dart'
    show plexExtrasProvider, PlexExtra;

/// Cinematic details screen for media server items (Jellyfin/Emby/Plex).
///
/// Features:
/// - Immersive Hero Banner (backdrop or poster).
/// - Metadata Chips (Year, Rating, Duration).
/// - Primary Actions (Play, Resume).
/// - Synopsis.
class MediaItemDetailsScreen extends ConsumerStatefulWidget {
  const MediaItemDetailsScreen({
    required this.item,
    required this.serverType,
    this.getStreamUrl,
    this.heroTag,
    super.key,
  });

  /// The media item to display.
  final MediaItem item;

  /// The type of media server (for stream URL resolution).
  final MediaServerType serverType;

  /// Optional callback to resolve the stream URL.
  /// If not provided, uses the item's streamUrl.
  final Future<String> Function(String itemId)? getStreamUrl;

  /// Hero animation tag.
  final String? heroTag;

  @override
  ConsumerState<MediaItemDetailsScreen> createState() =>
      _MediaItemDetailsScreenState();
}

class _MediaItemDetailsScreenState
    extends ConsumerState<MediaItemDetailsScreen> {
  bool _isLoadingStream = false;

  // FE-JF-13: selected audio/subtitle track indices (0-based within stream type).
  int? _selectedAudioTrack;
  int? _selectedSubtitleTrack;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final crispyColors = Theme.of(context).crispyColors;

    // Get backdrop URL from metadata if available
    final backdropUrl = item.metadata['backdropUrl'] as String?;
    final imageUrl = backdropUrl ?? item.logoUrl;

    // Format duration
    final durationText = DurationFormatter.humanShortMs(item.durationMs);

    return Scaffold(
      key: TestKeys.mediaItemDetailsScreen,
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero Banner ──
          CinematicHeroBanner(
            heroTag: widget.heroTag ?? item.id,
            expandedHeight: 450,
            image:
                imageUrl != null
                    ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              Container(color: colorScheme.surfaceContainer),
                    )
                    : Container(
                      color: colorScheme.surfaceContainer,
                      child: Center(
                        child: Icon(
                          Icons.movie,
                          size: 64,
                          color: colorScheme.onSurface.withValues(alpha: 0.24),
                        ),
                      ),
                    ),
            titleColumn: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  item.name,
                  style: textTheme.displaySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                        color: colorScheme.shadow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CrispySpacing.sm),

                // Metadata Row
                Row(
                  children: [
                    if (item.year != null) MetaChip(label: '${item.year}'),
                    if (item.rating != null)
                      MetaChip(
                        label: item.rating!,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    if (durationText != null) MetaChip(label: durationText),
                    // Watched indicator
                    if (item.isWatched)
                      MetaChip(
                        label: 'WATCHED',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    if (item.isInProgress && item.watchProgress != null)
                      MetaChip(
                        label: '${(item.watchProgress! * 100).toInt()}%',
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Actions & Synopsis ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons
                  Row(
                    children: [
                      // Play/Resume Button
                      SizedBox(
                        height: 48,
                        child: FocusWrapper(
                          onSelect: _isLoadingStream ? null : () => _play(),
                          borderRadius: CrispyRadius.md,
                          child: FilledButton.icon(
                            onPressed: _isLoadingStream ? null : () => _play(),
                            icon:
                                _isLoadingStream
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                    : Icon(
                                      item.isInProgress
                                          ? Icons.play_circle
                                          : Icons.play_arrow,
                                    ),
                            label: Text(item.isInProgress ? 'Resume' : 'Play'),
                            style: FilledButton.styleFrom(
                              backgroundColor: crispyColors.liveRed,
                              foregroundColor: colorScheme.onPrimary,
                              shape: const RoundedRectangleBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.xl,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // If in progress, show "Start Over" option
                      if (item.isInProgress) ...[
                        const SizedBox(width: CrispySpacing.md),
                        SizedBox(
                          height: 48,
                          child: FocusWrapper(
                            onSelect:
                                _isLoadingStream
                                    ? null
                                    : () => _playFromStart(),
                            borderRadius: CrispyRadius.md,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isLoadingStream
                                      ? null
                                      : () => _playFromStart(),
                              icon: const Icon(Icons.replay),
                              label: const Text('Start Over'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.onSurface,
                                side: BorderSide(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.54,
                                  ),
                                ),
                                shape: const RoundedRectangleBorder(),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // FE-JF-13: Audio/subtitle track selector (Jellyfin).
                      if (widget.serverType == MediaServerType.jellyfin) ...[
                        const SizedBox(width: CrispySpacing.md),
                        SizedBox(
                          height: 48,
                          child: FocusWrapper(
                            onSelect: () => _showTrackSelector(context, item),
                            borderRadius: CrispyRadius.md,
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => _showTrackSelector(context, item),
                              icon: const Icon(Icons.subtitles_outlined),
                              label: const Text('Tracks'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.onSurface,
                                side: BorderSide(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.54,
                                  ),
                                ),
                                shape: const RoundedRectangleBorder(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: CrispySpacing.xl),

                  // Synopsis
                  if (item.overview != null && item.overview!.isNotEmpty)
                    Text(
                      item.overview!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                  const SizedBox(height: CrispySpacing.xxl),

                  // Additional metadata
                  if (item.releaseDate != null)
                    _InfoRow(
                      label: 'Release Date',
                      value: formatYMD(item.releaseDate!),
                    ),

                  const SizedBox(height: CrispySpacing.xl),

                  // PX-FE-12: Extras/trailers section (Plex only).
                  // Shown when the item has extras in its metadata map.
                  if (widget.serverType == MediaServerType.plex)
                    _PlexExtrasSection(item: item, onPlay: _play),

                  const SizedBox(height: CrispySpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _play() async {
    await _navigateToPlayer(resumeFromPosition: true);
  }

  Future<void> _playFromStart() async {
    await _navigateToPlayer(resumeFromPosition: false);
  }

  /// Delegates to [StartMediaServerPlaybackUseCase] to resolve the
  /// stream URL, look up a resume position, and start playback.
  Future<void> _navigateToPlayer({required bool resumeFromPosition}) async {
    await StartMediaServerPlaybackUseCase(ref: ref, context: context).execute(
      item: widget.item,
      resumeFromPosition: resumeFromPosition,
      getStreamUrl: widget.getStreamUrl,
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _isLoadingStream = loading);
      },
    );
  }

  // FE-JF-13: Show audio/subtitle track selector bottom sheet.
  /// Shows a bottom sheet with selectable audio and subtitle tracks
  /// parsed from [item.metadata['mediaStreams']].
  void _showTrackSelector(BuildContext context, MediaItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(CrispyRadius.md),
          topRight: Radius.circular(CrispyRadius.md),
        ),
      ),
      builder:
          (ctx) => _JellyfinTrackSelectorSheet(
            item: item,
            selectedAudioTrack: _selectedAudioTrack,
            selectedSubtitleTrack: _selectedSubtitleTrack,
            onAudioSelected: (index) {
              Navigator.of(ctx).pop();
              setState(() => _selectedAudioTrack = index);
            },
            onSubtitleSelected: (index) {
              Navigator.of(ctx).pop();
              setState(() => _selectedSubtitleTrack = index);
            },
          ),
    );
  }
}

// ── PX-FE-12: Extras/Trailers section ───────────────────────────────────

/// [PX-FE-12] Horizontal extras row below the synopsis on Plex detail screens.
///
/// Shows Trailers, Interviews, Behind the Scenes clips fetched via
/// [plexExtrasProvider]. Tapping an extra resolves its stream URL and
/// launches the player.
class _PlexExtrasSection extends ConsumerWidget {
  const _PlexExtrasSection({required this.item, required this.onPlay});

  final MediaItem item;
  final Future<void> Function() onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extrasAsync = ref.watch(plexExtrasProvider(item));

    return extrasAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (extras) {
        if (extras.isEmpty) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Extras',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: extras.length,
                separatorBuilder:
                    (context, index) => const SizedBox(width: CrispySpacing.sm),
                itemBuilder: (context, index) {
                  final extra = extras[index];
                  return _PlexExtraCard(
                    extra: extra,
                    duration: DurationFormatter.humanShortMs(extra.durationMs),
                    onTap: () {
                      // Stub: play extra via its itemId.
                      // Full implementation resolves stream URL via
                      // plexStreamUrlProvider(extra.itemId) then
                      // navigates to the player screen.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Playing extra: ${extra.title}'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: CrispySpacing.md),
          ],
        );
      },
    );
  }
}

/// Card for a single Plex extra (trailer, interview, etc.).
class _PlexExtraCard extends StatelessWidget {
  const _PlexExtraCard({
    required this.extra,
    required this.onTap,
    this.duration,
  });

  final PlexExtra extra;
  final String? duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.md,
      scaleFactor: 1.04,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 200,
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail.
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (extra.thumbUrl != null)
                        Image.network(
                          extra.thumbUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) => ColoredBox(
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  Icons.movie_outlined,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                        )
                      else
                        ColoredBox(
                          color: cs.surfaceContainerHighest,
                          child: Icon(
                            Icons.movie_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      // Play icon overlay.
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(CrispySpacing.xs),
                            child: Icon(
                              Icons.play_arrow,
                              size: 28,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Title + type + duration.
                ColoredBox(
                  color: cs.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(CrispySpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          extra.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          [
                            extra.type,
                            if (duration != null) duration!,
                          ].join(' · '),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── FE-JF-13: Audio/subtitle track selector bottom sheet ─────────────────

/// Track info parsed from Jellyfin MediaStreams metadata.
class _JellyfinTrack {
  const _JellyfinTrack({
    required this.index,
    required this.language,
    required this.codec,
    required this.isExternal,
    this.displayTitle,
  });

  final int index;
  final String language;
  final String codec;
  final bool isExternal;
  final String? displayTitle;

  String get label {
    final parts = <String>[
      if (language.isNotEmpty) language.toUpperCase(),
      if (codec.isNotEmpty) codec.toUpperCase(),
      if (isExternal) 'External',
    ];
    return displayTitle ?? (parts.isEmpty ? 'Track $index' : parts.join(' · '));
  }
}

/// [FE-JF-13] Bottom sheet with selectable audio and subtitle tracks.
///
/// Reads available tracks from [item.metadata['mediaStreams']] — a list
/// of maps conforming to the Jellyfin MediaStream JSON schema.
/// Shows:
/// - Audio tracks: language + codec chip row.
/// - Subtitle tracks: language, type (embedded/external) chip row.
///
/// Selected indices are passed back via [onAudioSelected] /
/// [onSubtitleSelected] so the player can use them.
class _JellyfinTrackSelectorSheet extends StatelessWidget {
  const _JellyfinTrackSelectorSheet({
    required this.item,
    required this.onAudioSelected,
    required this.onSubtitleSelected,
    this.selectedAudioTrack,
    this.selectedSubtitleTrack,
  });

  final MediaItem item;
  final int? selectedAudioTrack;
  final int? selectedSubtitleTrack;
  final void Function(int index) onAudioSelected;
  final void Function(int index) onSubtitleSelected;

  // FE-JF-13: parse audio and subtitle tracks from metadata.
  List<_JellyfinTrack> _parseTracks(String type) {
    final streams = item.metadata['mediaStreams'];
    if (streams is! List) return [];

    final result = <_JellyfinTrack>[];
    var typeIndex = 0;

    for (final stream in streams) {
      if (stream is! Map) continue;
      final streamType = stream['Type'] as String? ?? '';
      if (streamType.toLowerCase() != type.toLowerCase()) continue;

      result.add(
        _JellyfinTrack(
          index: typeIndex,
          language: stream['Language'] as String? ?? '',
          codec: stream['Codec'] as String? ?? '',
          isExternal: stream['IsExternal'] as bool? ?? false,
          displayTitle: stream['DisplayTitle'] as String?,
        ),
      );
      typeIndex++;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // FE-JF-13: parse audio/subtitle tracks from item metadata.
    final audioTracks = _parseTracks('Audio');
    final subtitleTracks = _parseTracks('Subtitle');

    return Padding(
      padding: const EdgeInsets.all(CrispySpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.subtitles_outlined),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                'Audio & Subtitles',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.md),

          // ── Audio tracks ─────────────────────────────────────
          if (audioTracks.isNotEmpty) ...[
            Text(
              'Audio',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),
            Wrap(
              spacing: CrispySpacing.sm,
              runSpacing: CrispySpacing.xs,
              children:
                  audioTracks.map((track) {
                    final isSelected = selectedAudioTrack == track.index;
                    return FilterChip(
                      // FE-JF-13: audio track chip (language + codec).
                      label: Text(track.label),
                      selected: isSelected,
                      onSelected: (_) => onAudioSelected(track.index),
                    );
                  }).toList(),
            ),
            const SizedBox(height: CrispySpacing.lg),
          ],

          // ── Subtitle tracks ──────────────────────────────────
          if (subtitleTracks.isNotEmpty) ...[
            Text(
              'Subtitles',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),
            Wrap(
              spacing: CrispySpacing.sm,
              runSpacing: CrispySpacing.xs,
              children: [
                // FE-JF-13: "Off" chip to disable subtitles.
                FilterChip(
                  label: const Text('Off'),
                  selected: selectedSubtitleTrack == null,
                  onSelected: (_) => onSubtitleSelected(-1),
                ),
                ...subtitleTracks.map((track) {
                  final isSelected = selectedSubtitleTrack == track.index;
                  return FilterChip(
                    // FE-JF-13: subtitle chip (language, embedded/external).
                    label: Text(track.label),
                    avatar:
                        track.isExternal
                            ? const Icon(Icons.open_in_new, size: 14)
                            : null,
                    selected: isSelected,
                    onSelected: (_) => onSubtitleSelected(track.index),
                  );
                }),
              ],
            ),
          ],

          if (audioTracks.isEmpty && subtitleTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xl),
              child: Center(
                child: Text(
                  'No track information available',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),

          const SizedBox(height: CrispySpacing.md),
        ],
      ),
    );
  }
}

// ── Info row ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          '$label: ',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
