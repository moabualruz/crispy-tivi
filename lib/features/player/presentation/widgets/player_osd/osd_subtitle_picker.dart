import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/widgets/focus_wrapper.dart';
import '../../../domain/entities/playback_state.dart';
import '../../providers/player_providers.dart';
import 'osd_shared.dart';
import 'osd_track_picker.dart';
import 'subtitle_style_dialog.dart';

/// Shows the combined audio + subtitle track panel.
///
/// Netflix-style: slide-up panel from bottom-right
/// with two columns (AUDIO | SUBTITLES).
/// Animation: slide up + fade in, 200ms.
void showSubtitleTrackPicker(
  BuildContext context,
  WidgetRef ref,
  PlaybackState state,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black26,
    transitionDuration: CrispyAnimation.osdShow,
    transitionBuilder: (ctx, anim, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0.3),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: anim, curve: CrispyAnimation.enterCurve),
        ),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, anim, _) {
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: CrispySpacing.lg, bottom: 80),
          child: _CombinedTrackPanel(
            state: state,
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      );
    },
  );
}

/// Two-column audio + subtitle picker panel.
class _CombinedTrackPanel extends ConsumerWidget {
  const _CombinedTrackPanel({required this.state, required this.onClose});

  final PlaybackState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final hasAudio = state.audioTracks.length > 1;
    final hasSubs = state.subtitleTracks.isNotEmpty;

    // Build audio track items.
    final audioItems =
        state.audioTracks
            .map(
              (t) => TrackItem(
                index: t.id,
                label:
                    t.language != null && t.language!.isNotEmpty
                        ? '${t.title} (${t.language})'
                        : t.title,
              ),
            )
            .toList();

    // Build subtitle items with "Off" option.
    final subItems = [
      const TrackItem(index: -1, label: 'Off'),
      ...state.subtitleTracks.map(
        (t) => TrackItem(
          index: t.id,
          label:
              t.language != null && t.language!.isNotEmpty
                  ? '${t.title} (${t.language})'
                  : t.title,
        ),
      ),
    ];

    return Material(
      color: osdPanelColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.md,
                vertical: CrispySpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Audio & Subtitles',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Close',
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onClose,
                      tooltip: 'Close',
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Two columns
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Audio column
                  if (hasAudio)
                    Expanded(
                      child: _TrackColumn(
                        title: 'AUDIO',
                        items: audioItems,
                        selectedIndex: state.selectedAudioTrackId,
                        onSelected: (id) {
                          ref.read(playerServiceProvider).setAudioTrack(id);
                        },
                        textTheme: textTheme,
                      ),
                    ),

                  if (hasAudio && hasSubs)
                    const VerticalDivider(color: Colors.white12, width: 1),

                  // Subtitles column
                  if (hasSubs)
                    Expanded(
                      child: _TrackColumn(
                        title: 'SUBTITLES',
                        items: subItems,
                        selectedIndex: state.selectedSubtitleTrackId ?? -1,
                        onSelected: (id) {
                          ref.read(playerServiceProvider).setSubtitleTrack(id);
                        },
                        textTheme: textTheme,
                        onCcStyle: () {
                          Navigator.pop(context);
                          showSubtitleStyleDialog(context);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single column of track items with a header label.
///
/// When [onCcStyle] is provided (subtitles column only), a
/// "CC Style" footer button is rendered below the track list.
class _TrackColumn extends StatelessWidget {
  const _TrackColumn({
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.textTheme,
    this.onCcStyle,
  });

  final String title;
  final List<TrackItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final TextTheme textTheme;

  /// Optional callback that opens the CC style dialog.
  ///
  /// Only the subtitles column passes this; the audio column
  /// leaves it null, so no footer is rendered there.
  final VoidCallback? onCcStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column header
        Padding(
          padding: const EdgeInsets.only(
            left: CrispySpacing.md,
            top: CrispySpacing.sm,
            bottom: CrispySpacing.xs,
          ),
          child: Text(
            title,
            style: textTheme.labelSmall?.copyWith(
              color: osdGrayText,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Track list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final selected = item.index == selectedIndex;
              return Semantics(
                label: item.label,
                selected: selected,
                button: true,
                child: FocusWrapper(
                  onSelect: () => onSelected(item.index),
                  borderRadius: CrispyRadius.tv,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                      vertical: CrispySpacing.sm,
                    ),
                    child: Row(
                      children: [
                        // Radio indicator
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected ? Colors.white : osdGrayText,
                          size: 18,
                        ),
                        const SizedBox(width: CrispySpacing.sm),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: selected ? Colors.white : osdGrayText,
                              fontSize: 14,
                              fontWeight:
                                  selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // CC Style footer — subtitles column only
        if (onCcStyle != null) ...[
          const Divider(color: Colors.white12, height: 1),
          FocusWrapper(
            onSelect: onCcStyle!,
            borderRadius: CrispyRadius.tv,
            child: InkWell(
              onTap: onCcStyle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.closed_caption_outlined,
                      color: osdGrayText,
                      size: 16,
                    ),
                    const SizedBox(width: CrispySpacing.sm),
                    Text(
                      'CC Style',
                      style: textTheme.labelSmall?.copyWith(
                        color: osdGrayText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: osdGrayText,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
