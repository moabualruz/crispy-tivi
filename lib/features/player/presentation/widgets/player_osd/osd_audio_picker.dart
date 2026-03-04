import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/widgets/responsive_layout.dart';
import '../../../../../core/widgets/side_panel.dart';
import '../../../domain/entities/playback_state.dart';
import '../../providers/player_providers.dart';
import 'osd_track_picker.dart';

/// Shows the audio track picker as a side panel
/// (large screens) or bottom sheet (small screens).
void showAudioTrackPicker(
  BuildContext context,
  WidgetRef ref,
  PlaybackState state,
) {
  final tracks = state.audioTracks;
  if (tracks.isEmpty) return;

  final items =
      tracks
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

  if (context.isLarge) {
    _showSidePanel(
      context,
      title: 'Audio Track',
      child: TrackPickerList(
        items: items,
        selectedIndex: state.selectedAudioTrackId,
        onSelected: (index) {
          ref.read(playerServiceProvider).setAudioTrack(index);
        },
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.zero),
      ),
      builder:
          (ctx) => TrackPickerSheet(
            title: 'Audio Track',
            child: TrackPickerList(
              items: items,
              selectedIndex: state.selectedAudioTrackId,
              onSelected: (index) {
                ref.read(playerServiceProvider).setAudioTrack(index);
                Navigator.pop(ctx);
              },
            ),
          ),
    );
  }
}

void _showSidePanel(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    transitionDuration: CrispyAnimation.normal,
    pageBuilder:
        (ctx, anim1, anim2) => SidePanel(
          title: title,
          onClose: () => Navigator.pop(ctx),
          child: child,
        ),
  );
}
