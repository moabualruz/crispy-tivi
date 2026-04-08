import 'package:flutter/material.dart';

import '../../domain/entities/multiview_session.dart';

/// Presentation-layer icon mapping for [MultiViewPreset].
///
/// Extracted from the domain entity to keep domain free of
/// Flutter imports (DDD boundary rule).
extension MultiViewPresetUi on MultiViewPreset {
  /// The Material icon for this preset.
  IconData get icon => switch (this) {
    MultiViewPreset.sideBySide => Icons.view_column_outlined,
    MultiViewPreset.quad => Icons.grid_view_outlined,
    MultiViewPreset.pictureInPicture => Icons.picture_in_picture_outlined,
    MultiViewPreset.grid => Icons.apps_outlined,
  };
}
