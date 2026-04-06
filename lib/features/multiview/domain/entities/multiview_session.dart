import 'package:equatable/equatable.dart';

import 'active_stream.dart';

/// Named layout presets for Multi-View.
///
/// Each preset maps to a [MultiViewLayout] and carries a display
/// name. Icon mapping lives in the presentation layer via
/// [MultiViewPresetUi] extension.
enum MultiViewPreset {
  /// Two streams side by side (2 columns × 1 row).
  sideBySide(label: 'Side by Side', layout: MultiViewLayout.twoByOne),

  /// Four streams in a 2×2 grid.
  quad(label: 'Quad', layout: MultiViewLayout.twoByTwo),

  /// One large main stream with a small inset in the corner (3×3,
  /// caller sets the first slot as the "main" channel).
  pictureInPicture(
    label: 'Picture-in-Picture',
    layout: MultiViewLayout.twoByOne,
  ),

  /// Nine-stream full grid (3 columns × 3 rows).
  grid(label: 'Grid', layout: MultiViewLayout.threeByThree);

  const MultiViewPreset({required this.label, required this.layout});

  /// Human-readable preset name shown in the chip label.
  final String label;

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
