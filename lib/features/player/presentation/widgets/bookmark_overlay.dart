// FE-PS-15: Video bookmarks / timestamp pins
import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../providers/player_providers.dart';
import 'player_osd/osd_shared.dart';

// ─────────────────────────────────────────────────────────────
//  Bookmark model
// ─────────────────────────────────────────────────────────────

/// A user-defined timestamp pin in a video.
@immutable
class VideoBookmark {
  const VideoBookmark({
    required this.id,
    required this.position,
    required this.createdAt,
    this.label,
  });

  /// Creates a [VideoBookmark] from a backend map.
  factory VideoBookmark.fromMap(Map<String, dynamic> m) {
    return VideoBookmark(
      id: m['id'] as String,
      position: Duration(milliseconds: (m['position_ms'] as num).toInt()),
      label: m['label'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (m['created_at'] as num).toInt(),
      ),
    );
  }

  /// Unique bookmark ID (UUID or timestamp string).
  final String id;

  /// Playback position of the bookmark.
  final Duration position;

  /// Optional user label (e.g. "Best scene").
  final String? label;

  /// When the bookmark was created.
  final DateTime createdAt;

  VideoBookmark copyWith({String? label}) {
    return VideoBookmark(
      id: id,
      position: position,
      label: label ?? this.label,
      createdAt: createdAt,
    );
  }

  /// Converts to a backend map for persistence.
  Map<String, dynamic> toMap(String contentId, String contentType) {
    return {
      'id': id,
      'content_id': contentId,
      'content_type': contentType,
      'position_ms': position.inMilliseconds,
      'label': label,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VideoBookmark && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────
//  Bookmark provider (FE-PS-15)
// ─────────────────────────────────────────────────────────────

/// Manages the list of video bookmarks for the current playback
/// session, persisted via [CacheService].
///
/// Call [loadForContent] when a new stream opens to fetch
/// persisted bookmarks. Mutations are auto-persisted.
class BookmarkNotifier extends Notifier<List<VideoBookmark>> {
  String? _contentId;
  String? _contentType;

  @override
  List<VideoBookmark> build() => const [];

  /// Loads persisted bookmarks for [contentId] from the backend.
  Future<void> loadForContent(String contentId, String contentType) async {
    _contentId = contentId;
    _contentType = contentType;
    final cache = ref.read(cacheServiceProvider);
    final maps = await cache.loadBookmarks(contentId);
    state =
        maps.map(VideoBookmark.fromMap).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Adds a bookmark at [position] with an optional [label].
  ///
  /// Returns the newly created [VideoBookmark].
  Future<VideoBookmark> add(Duration position, {String? label}) async {
    final bookmark = VideoBookmark(
      id:
          '${position.inMilliseconds}_'
          '${DateTime.now().millisecondsSinceEpoch}',
      position: position,
      label: label,
      createdAt: DateTime.now(),
    );
    state = [...state, bookmark]
      ..sort((a, b) => a.position.compareTo(b.position));

    if (_contentId != null && _contentType != null) {
      final cache = ref.read(cacheServiceProvider);
      await cache.saveBookmark(bookmark.toMap(_contentId!, _contentType!));
    }
    return bookmark;
  }

  /// Removes the bookmark with [id].
  Future<void> remove(String id) async {
    state = state.where((b) => b.id != id).toList();
    final cache = ref.read(cacheServiceProvider);
    await cache.deleteBookmark(id);
  }

  /// Updates the label of bookmark [id].
  Future<void> updateLabel(String id, String newLabel) async {
    state = [
      for (final b in state)
        if (b.id == id) b.copyWith(label: newLabel) else b,
    ];

    if (_contentId != null && _contentType != null) {
      final updated = state.where((b) => b.id == id).firstOrNull;
      if (updated != null) {
        final cache = ref.read(cacheServiceProvider);
        await cache.saveBookmark(updated.toMap(_contentId!, _contentType!));
      }
    }
  }

  /// Clears local bookmark state (call when a new media item
  /// loads). Does NOT delete persisted bookmarks.
  void clear() {
    _contentId = null;
    _contentType = null;
    state = const [];
  }

  /// Returns the bookmark closest to [position] within
  /// [snapRadius], or null if none is that close.
  VideoBookmark? nearestTo(
    Duration position, {
    Duration snapRadius = const Duration(seconds: 2),
  }) {
    VideoBookmark? nearest;
    Duration minDiff = snapRadius + const Duration(milliseconds: 1);
    for (final b in state) {
      final diff = (b.position - position).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = b;
      }
    }
    return nearest;
  }
}

/// Global bookmark provider.
final bookmarkProvider =
    NotifierProvider<BookmarkNotifier, List<VideoBookmark>>(
      BookmarkNotifier.new,
    );

// ─────────────────────────────────────────────────────────────
//  Bookmark seek bar overlay (FE-PS-15)
// ─────────────────────────────────────────────────────────────

/// Draws diamond-shaped bookmark markers on the seek bar track.
///
/// Tapping a bookmark seeks to its position. Long-pressing shows
/// an edit/delete context menu.
///
/// Place this as a [Positioned.fill] child on top of the
/// [SeekBarWithPreview] in a [Stack].
class BookmarkSeekBarOverlay extends ConsumerWidget {
  const BookmarkSeekBarOverlay({
    required this.duration,
    required this.barWidth,
    required this.onSeek,
    super.key,
  });

  /// Total video duration.
  final Duration duration;

  /// Pixel width of the seek bar (from LayoutBuilder).
  final double barWidth;

  /// Callback when a bookmark is tapped. Receives a progress
  /// fraction (0.0–1.0).
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    if (bookmarks.isEmpty || duration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final bm in bookmarks)
          _BookmarkPin(
            bookmark: bm,
            duration: duration,
            barWidth: barWidth,
            onTap: () {
              final frac = bm.position.inMilliseconds / duration.inMilliseconds;
              onSeek(frac.clamp(0.0, 1.0));
            },
            onLongPress: (context) => _showBookmarkMenu(context, ref, bm),
          ),
      ],
    );
  }

  void _showBookmarkMenu(
    BuildContext context,
    WidgetRef ref,
    VideoBookmark bookmark,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BookmarkEditSheet(
            bookmark: bookmark,
            onSave: (newLabel) {
              ref
                  .read(bookmarkProvider.notifier)
                  .updateLabel(bookmark.id, newLabel);
            },
            onDelete: () {
              ref.read(bookmarkProvider.notifier).remove(bookmark.id);
            },
          ),
    );
  }
}

class _BookmarkPin extends StatelessWidget {
  const _BookmarkPin({
    required this.bookmark,
    required this.duration,
    required this.barWidth,
    required this.onTap,
    required this.onLongPress,
  });

  final VideoBookmark bookmark;
  final Duration duration;
  final double barWidth;
  final VoidCallback onTap;
  final void Function(BuildContext) onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (duration.inMilliseconds == 0) return const SizedBox.shrink();

    final frac = bookmark.position.inMilliseconds / duration.inMilliseconds;
    final x = frac * barWidth;

    return Positioned(
      // Centre the 12×12 diamond on x
      left: x - 6,
      top: 0,
      bottom: 0,
      child: Semantics(
        button: true,
        label: context.l10n.playerBookmark,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: () => onLongPress(context),
          child: Align(
            alignment: Alignment.center,
            child: Tooltip(
              message:
                  bookmark.label ?? DurationFormatter.clock(bookmark.position),
              child: Transform.rotate(
                angle: 0.785398, // 45 degrees in radians
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(CrispyRadius.tvSm),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bookmark edit bottom sheet (FE-PS-15)
// ─────────────────────────────────────────────────────────────

/// Bottom sheet for editing or deleting a bookmark.
class BookmarkEditSheet extends StatefulWidget {
  const BookmarkEditSheet({
    required this.bookmark,
    required this.onSave,
    required this.onDelete,
    super.key,
  });

  final VideoBookmark bookmark;
  final ValueChanged<String> onSave;
  final VoidCallback onDelete;

  @override
  State<BookmarkEditSheet> createState() => _BookmarkEditSheetState();
}

class _BookmarkEditSheetState extends State<BookmarkEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.bookmark.label ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + CrispySpacing.md,
        left: CrispySpacing.md,
        right: CrispySpacing.md,
        top: CrispySpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(CrispyRadius.tv),
          topRight: Radius.circular(CrispyRadius.tv),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: CrispySpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
              ),
            ),
          ),

          Text(
            context.l10n.playerEditBookmark,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: CrispySpacing.md),

          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.playerBookmarkLabelHint,
              labelText: context.l10n.playerBookmarkLabelInput,
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            style: TextStyle(color: colorScheme.onSurface),
            onSubmitted: (_) => _save(),
          ),

          const SizedBox(height: CrispySpacing.md),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDelete();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                ),
              ),

              const SizedBox(width: CrispySpacing.md),

              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(context.l10n.commonSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop();
    widget.onSave(_controller.text.trim());
  }
}

// ─────────────────────────────────────────────────────────────
//  OSD Bookmark button (FE-PS-15)
// ─────────────────────────────────────────────────────────────

/// OSD icon button that adds a bookmark at the current position.
///
/// Briefly shows a confirmation snackbar on success.
class OsdBookmarkButton extends ConsumerWidget {
  const OsdBookmarkButton({this.order, super.key});

  final double? order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OsdIconButton(
      icon: Icons.bookmark_add_outlined,
      tooltip: context.l10n.playerBookmark,
      order: order,
      onPressed: () => _addBookmark(context, ref),
    );
  }

  void _addBookmark(BuildContext context, WidgetRef ref) {
    final position = ref.read(
      playbackStateProvider.select((s) => s.value?.position ?? Duration.zero),
    );
    ref.read(bookmarkProvider.notifier).add(position);
    ref.read(osdStateProvider.notifier).show();

    final label = DurationFormatter.clock(position);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.playerBookmarkAdded(label)),
        duration: CrispyAnimation.normal * 2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
