import 'dart:async';

import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/segment_skip_config.dart';
import '../../domain/utils/skip_segment_utils.dart';
import '../providers/player_providers.dart';
import 'player_osd/osd_shared.dart';

/// Duration the skip button stays visible without
/// user interaction before auto-fading.
const _kSkipAutoHideDuration = Duration(seconds: 8);

/// Tracks which [SegmentType]s have been auto-skipped in
/// the current playback session (for "once" mode).
///
/// Reset when a new playback session starts (provider is
/// auto-disposed with the player widget tree).
class AutoSkippedSegmentsNotifier extends Notifier<Set<SegmentType>> {
  @override
  Set<SegmentType> build() => {};

  /// Record that [type] has been auto-skipped.
  void markSkipped(SegmentType type) {
    state = {...state, type};
  }

  /// Clear all tracked auto-skips (e.g. on new content).
  void reset() {
    state = {};
  }
}

/// Provider for the set of segment types auto-skipped this session.
final autoSkippedSegmentsProvider =
    NotifierProvider<AutoSkippedSegmentsNotifier, Set<SegmentType>>(
      AutoSkippedSegmentsNotifier.new,
    );

/// Overlay button that appears when playback position
/// enters an intro, recap, or credits segment.
///
/// Behavior depends on the per-type [SegmentSkipMode]:
/// - [SegmentSkipMode.none]: button is suppressed.
/// - [SegmentSkipMode.ask]: button shown, user must tap.
/// - [SegmentSkipMode.once]: auto-skip first occurrence,
///   then show button for subsequent occurrences.
/// - [SegmentSkipMode.auto]: always auto-skip silently.
///
/// Auto-fades after [_kSkipAutoHideDuration] (8 s) if
/// the user does not tap it. Tapping seeks past the
/// segment end.
///
/// Positioned above the OSD bottom bar:
/// `bottom: kOsdBottomBarHeight + CrispySpacing.md`.
class SkipSegmentButton extends ConsumerStatefulWidget {
  const SkipSegmentButton({super.key});

  @override
  ConsumerState<SkipSegmentButton> createState() => _SkipSegmentButtonState();
}

class _SkipSegmentButtonState extends ConsumerState<SkipSegmentButton>
    with SingleTickerProviderStateMixin {
  /// Currently active segment (null when position is
  /// outside all segments).
  SkipSegment? _activeSegment;

  /// Label shown on the button.
  String _label = 'Skip';

  Timer? _autoHideTimer;
  bool _visible = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: CrispyAnimation.normal,
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: CrispyAnimation.enterCurve,
      reverseCurve: CrispyAnimation.exitCurve,
    );
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _show(SkipSegment segment, String label) {
    _autoHideTimer?.cancel();
    setState(() {
      _activeSegment = segment;
      _label = label;
      _visible = true;
    });
    _fadeCtrl.forward();
    _autoHideTimer = Timer(_kSkipAutoHideDuration, _hide);
  }

  void _hide() {
    _autoHideTimer?.cancel();
    _fadeCtrl.reverse().then((_) {
      if (mounted) {
        setState(() {
          _visible = false;
          _activeSegment = null;
        });
      }
    });
  }

  void _seekPast(SkipSegment seg) {
    ref.read(playerServiceProvider).seek(seg.end);
    _hide();
  }

  void _autoSkip(SkipSegment seg, SegmentType type) {
    ref.read(playerServiceProvider).seek(seg.end);
    // For "once" mode, record that this type was auto-skipped.
    ref.read(autoSkippedSegmentsProvider.notifier).markSkipped(type);
    if (_visible) _hide();
  }

  @override
  Widget build(BuildContext context) {
    final skipConfig = ref.watch(segmentSkipConfigProvider);
    final autoSkipped = ref.watch(autoSkippedSegmentsProvider);

    ref.listen(
      playbackStateProvider.select(
        (s) => (
          position: s.value?.position,
          segments: s.value?.skipSegments ?? const <SkipSegment>[],
        ),
      ),
      (prev, next) {
        final pos = next.position;
        final segments = next.segments;
        if (pos == null || segments.isEmpty) {
          if (_visible) _hide();
          return;
        }

        SkipSegment? hit;
        for (final seg in segments) {
          if (seg.containsPosition(pos)) {
            hit = seg;
            break;
          }
        }

        if (hit == null) {
          if (_visible) _hide();
          return;
        }

        // Same segment already active — no action needed.
        if (hit == _activeSegment) return;

        final type = inferSegmentType(hit, segments);
        final mode = skipConfig[type] ?? SegmentSkipMode.ask;

        switch (mode) {
          case SegmentSkipMode.none:
            if (_visible) _hide();
          case SegmentSkipMode.auto:
            _autoSkip(hit, type);
          case SegmentSkipMode.once:
            if (autoSkipped.contains(type)) {
              // Already auto-skipped once — show button.
              _show(hit, segmentLabel(hit, segments));
            } else {
              _autoSkip(hit, type);
            }
          case SegmentSkipMode.ask:
            _show(hit, segmentLabel(hit, segments));
        }
      },
    );

    if (!_visible) return const SizedBox.shrink();

    return Positioned(
      right: CrispySpacing.xl,
      bottom: kOsdBottomBarHeight + CrispySpacing.md,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: _SkipButton(
          label: _label,
          onTap: () {
            final seg = _activeSegment;
            if (seg != null) _seekPast(seg);
          },
        ),
      ),
    );
  }
}

/// Visual chip for the skip action.
class _SkipButton extends StatefulWidget {
  const _SkipButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: context.l10n.playerSkipSegment,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: CrispyAnimation.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.md,
              vertical: CrispySpacing.sm,
            ),
            decoration: BoxDecoration(
              color:
                  _hovered
                      ? colorScheme.onSurface.withValues(alpha: 0.9)
                      : colorScheme.surface.withValues(alpha: 0.85),
              border: Border.all(color: CrispyColors.brandRed, width: 2),
              borderRadius: BorderRadius.circular(CrispyRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: textTheme.labelLarge?.copyWith(
                    color:
                        _hovered ? colorScheme.surface : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: CrispySpacing.xs),
                Icon(
                  Icons.skip_next_rounded,
                  size: 18,
                  color: _hovered ? colorScheme.surface : CrispyColors.brandRed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
