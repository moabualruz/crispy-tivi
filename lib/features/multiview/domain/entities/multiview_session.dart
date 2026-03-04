import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'active_stream.dart';

/// Named layout presets for Multi-View.
///
/// Each preset maps to a [MultiViewLayout] and carries a display
/// name and a representative Material icon.
enum MultiViewPreset {
  /// Two streams side by side (2 columns × 1 row).
  sideBySide(
    label: 'Side by Side',
    icon: Icons.view_column_outlined,
    layout: MultiViewLayout.twoByOne,
  ),

  /// Four streams in a 2×2 grid.
  quad(
    label: 'Quad',
    icon: Icons.grid_view_outlined,
    layout: MultiViewLayout.twoByTwo,
  ),

  /// One large main stream with a small inset in the corner (3×3,
  /// caller sets the first slot as the "main" channel).
  pictureInPicture(
    label: 'Picture-in-Picture',
    icon: Icons.picture_in_picture_outlined,
    layout: MultiViewLayout.twoByOne,
  ),

  /// Nine-stream full grid (3 columns × 3 rows).
  grid(
    label: 'Grid',
    icon: Icons.apps_outlined,
    layout: MultiViewLayout.threeByThree,
  );

  const MultiViewPreset({
    required this.label,
    required this.icon,
    required this.layout,
  });

  /// Human-readable preset name shown in the chip label.
  final String label;

  /// Material icon representing the layout shape.
  final IconData icon;

  /// Underlying [MultiViewLayout] this preset uses.
  final MultiViewLayout layout;
}

/// State of the Multi-View session.
class MultiViewSession extends Equatable {
  const MultiViewSession({
    this.layout = MultiViewLayout.twoByTwo,
    this.preset = MultiViewPreset.quad,
    this.slots = const [],
    this.audioFocusIndex = 0,
  });

  final MultiViewLayout layout;

  /// Active named preset (drives the chip selection).
  final MultiViewPreset preset;

  final List<ActiveStream?> slots; // Null means empty slot
  final int audioFocusIndex; // Index of the slot with audio (if valid)

  MultiViewSession copyWith({
    MultiViewLayout? layout,
    MultiViewPreset? preset,
    List<ActiveStream?>? slots,
    int? audioFocusIndex,
  }) {
    return MultiViewSession(
      layout: layout ?? this.layout,
      preset: preset ?? this.preset,
      slots: slots ?? this.slots,
      audioFocusIndex: audioFocusIndex ?? this.audioFocusIndex,
    );
  }

  @override
  List<Object?> get props => [layout, preset, slots, audioFocusIndex];
}

enum MultiViewLayout {
  twoByOne(2, 1, 2),
  twoByTwo(2, 2, 4),
  threeByThree(3, 3, 9);

  const MultiViewLayout(this.columns, this.rows, this.cellCount);
  final int columns;
  final int rows;
  final int cellCount;
}
