import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/entities/thumbnail_sprite.dart';
import '../providers/thumbnail_providers.dart';
import 'buffer_range_painter.dart';
import 'thumbnail_preview_popup.dart';

/// Custom seek bar with thumbnail preview on hover.
///
/// Replaces the standard Flutter [Slider] for VOD playback.
/// Shows a thumbnail popup when the mouse hovers over the track.
class SeekBarWithPreview extends ConsumerStatefulWidget {
  const SeekBarWithPreview({
    required this.progress,
    required this.duration,
    required this.onSeek,
    this.bufferProgress = 0.0,
    this.bufferRanges,
    this.skipSegments = const [],
    this.thumbnailSource,
    this.accentColor,
    this.trackHeight = 3.0,
    this.thumbRadius = 6.0,
    super.key,
  });

  /// Current playback progress (0.0 to 1.0).
  final double progress;

  /// Buffered progress (0.0 to 1.0).
  final double bufferProgress;

  /// Optional multi-range cache segments (normalized 0.0–1.0).
  ///
  /// When provided, replaces the single [bufferProgress] bar
  /// with a [BufferRangePainter] showing all cached regions.
  final List<(double start, double end)>? bufferRanges;

  /// Skip segments to display as colored bars on the track.
  final List<SkipSegment> skipSegments;

  /// Total video duration.
  final Duration duration;

  /// Callback when user seeks to a new position.
  final ValueChanged<double> onSeek;

  /// Optional thumbnail data for preview (VTT or BIF).
  final ThumbnailSource? thumbnailSource;

  /// Accent color for the active track.
  final Color? accentColor;

  /// Height of the progress track.
  final double trackHeight;

  /// Radius of the thumb indicator.
  final double thumbRadius;

  @override
  ConsumerState<SeekBarWithPreview> createState() => _SeekBarWithPreviewState();
}

class _SeekBarWithPreviewState extends ConsumerState<SeekBarWithPreview> {
  double? _hoverX;
  bool _isHovering = false;
  bool _isDragging = false;
  bool _isFocused = false;
  double _dragProgress = 0.0;

  /// Width of the seek bar (measured on layout).
  double _seekBarWidth = 0;

  /// Seek step per arrow key press (2%).
  static const _seekStep = 0.02;

  /// Whether the track should be expanded (hover,
  /// drag, or focus).
  bool get _isExpanded => _isHovering || _isDragging || _isFocused;

  /// Effective progress to display.
  double get _effectiveProgress =>
      _isDragging ? _dragProgress : widget.progress;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      final target = (widget.progress - _seekStep).clamp(0.0, 1.0);
      widget.onSeek(target);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final target = (widget.progress + _seekStep).clamp(0.0, 1.0);
      widget.onSeek(target);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = widget.accentColor ?? colorScheme.primary;

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _seekBarWidth = constraints.maxWidth;

          return MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) {
              setState(() {
                _isHovering = false;
                _hoverX = null;
              });
              ref.read(seekBarHoverNotifierProvider.notifier).clearHover();
            },
            onHover: (event) {
              setState(() => _hoverX = event.localPosition.dx);
              _updateHoverPosition(event.localPosition.dx);
            },
            child: GestureDetector(
              onTapDown: (details) => _handleSeek(details.localPosition.dx),
              onHorizontalDragStart: (details) {
                if (_seekBarWidth <= 0) return;
                setState(() {
                  _isDragging = true;
                  _dragProgress = (details.localPosition.dx / _seekBarWidth)
                      .clamp(0.0, 1.0);
                });
              },
              onHorizontalDragUpdate: (details) {
                if (_seekBarWidth <= 0) return;
                setState(() {
                  _dragProgress = (details.localPosition.dx / _seekBarWidth)
                      .clamp(0.0, 1.0);
                  _hoverX = details.localPosition.dx;
                });
                _updateHoverPosition(details.localPosition.dx);
              },
              onHorizontalDragEnd: (_) {
                if (_isDragging) {
                  widget.onSeek(_dragProgress);
                }
                setState(() => _isDragging = false);
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: widget.thumbRadius * 2 + 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Track
                    _buildTrack(accentColor, colorScheme),

                    // Thumb
                    _buildThumb(accentColor, colorScheme),

                    // Thumbnail preview popup
                    if (_isHovering && _hoverX != null && !_isDragging)
                      _buildThumbnailPopup(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the progress track (background + buffer + active).
  Widget _buildTrack(Color accentColor, ColorScheme colorScheme) {
    final h = _isExpanded ? widget.trackHeight * 2 : widget.trackHeight;
    final radius = BorderRadius.circular(h / 2);

    return Positioned.fill(
      child: Center(
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          curve: CrispyAnimation.enterCurve,
          height: h,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                // Background track
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                // Buffer ranges (multi-segment) or single bar
                if (widget.bufferRanges != null &&
                    widget.bufferRanges!.isNotEmpty)
                  CustomPaint(
                    size: Size.infinite,
                    painter: BufferRangePainter(
                      ranges: widget.bufferRanges!,
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      trackHeight: h,
                    ),
                  )
                else if (widget.bufferProgress > 0)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.bufferProgress.clamp(0.0, 1.0),
                    child: Container(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                // Skip segment colored bars
                if (widget.skipSegments.isNotEmpty &&
                    widget.duration.inMilliseconds > 0)
                  CustomPaint(
                    size: Size.infinite,
                    painter: _SegmentBarPainter(
                      segments: widget.skipSegments,
                      durationMs: widget.duration.inMilliseconds,
                      trackHeight: h,
                    ),
                  ),
                // Played progress (accent)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _effectiveProgress.clamp(0.0, 1.0),
                  child: Container(color: accentColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the thumb indicator.
  ///
  /// White circle, 12-16px, only visible on hover,
  /// drag, or focus -- cinematic-style.
  Widget _buildThumb(Color accentColor, ColorScheme colorScheme) {
    final thumbX = _effectiveProgress * _seekBarWidth;
    final r = widget.thumbRadius;
    final visible = _isExpanded;
    final size = visible ? r * 2 : 0.0;

    return Positioned(
      left: thumbX - r,
      child: AnimatedContainer(
        duration: CrispyAnimation.fast,
        curve: CrispyAnimation.enterCurve,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.onSurface,
          boxShadow:
              visible
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
      ),
    );
  }

  /// Builds the thumbnail preview popup above the hover position.
  Widget _buildThumbnailPopup() {
    final hoverPosition = ref.watch(seekBarHoverPositionProvider);
    if (hoverPosition == null) return const SizedBox.shrink();

    // Get thumbnail region if available
    ThumbnailRegion? region;
    if (widget.thumbnailSource != null) {
      region = widget.thumbnailSource!.getRegionAt(hoverPosition);
    }

    // Calculate popup position with edge clamping
    const popupWidth =
        ThumbnailPreviewPopup.thumbnailWidth + CrispySpacing.xs * 2;
    final clampedX = _hoverX!.clamp(
      popupWidth / 2,
      _seekBarWidth - popupWidth / 2,
    );

    return Positioned(
      left: clampedX - popupWidth / 2,
      bottom: widget.thumbRadius * 2 + CrispySpacing.sm,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: CrispyAnimation.fast,
        child:
            region != null
                ? ThumbnailPreviewPopup(position: hoverPosition, region: region)
                : TimestampOnlyPopup(position: hoverPosition),
      ),
    );
  }

  /// Updates the hover position in the provider.
  void _updateHoverPosition(double x) {
    ref
        .read(seekBarHoverNotifierProvider.notifier)
        .updateHover(
          xPosition: x,
          seekBarWidth: _seekBarWidth,
          duration: widget.duration,
        );
  }

  /// Handles seeking to a position.
  void _handleSeek(double x) {
    if (_seekBarWidth <= 0) return;
    final progress = (x / _seekBarWidth).clamp(0.0, 1.0);
    widget.onSeek(progress);
  }
}

/// Paints colored bars on the seek bar track for skip segments.
///
/// Uses a semi-transparent yellow-orange for all segment types
/// so they stand out against both the track background and the
/// played progress bar.
class _SegmentBarPainter extends CustomPainter {
  _SegmentBarPainter({
    required this.segments,
    required this.durationMs,
    required this.trackHeight,
  });

  final List<SkipSegment> segments;
  final int durationMs;
  final double trackHeight;

  static const _segmentColor = CrispyColors.segmentHighlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationMs <= 0) return;

    final paint =
        Paint()
          ..color = _segmentColor
          ..style = PaintingStyle.fill;

    for (final seg in segments) {
      final startFraction = (seg.start.inMilliseconds / durationMs).clamp(
        0.0,
        1.0,
      );
      final endFraction = (seg.end.inMilliseconds / durationMs).clamp(0.0, 1.0);

      final left = startFraction * size.width;
      final right = endFraction * size.width;
      if (right <= left) continue;

      canvas.drawRect(Rect.fromLTWH(left, 0, right - left, trackHeight), paint);
    }
  }

  @override
  bool shouldRepaint(_SegmentBarPainter oldDelegate) =>
      !identical(segments, oldDelegate.segments) ||
      durationMs != oldDelegate.durationMs ||
      trackHeight != oldDelegate.trackHeight;
}
