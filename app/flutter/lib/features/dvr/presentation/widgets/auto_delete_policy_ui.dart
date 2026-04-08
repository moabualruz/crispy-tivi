import 'package:flutter/material.dart';

import '../../domain/entities/recording.dart';

/// Presentation-layer icon mapping for [AutoDeletePolicy].
///
/// Extracted from the domain entity to keep domain free of
/// Flutter imports (DDD boundary rule).
extension AutoDeletePolicyUi on AutoDeletePolicy {
  /// The Material icon for this policy.
  IconData get icon => switch (this) {
    AutoDeletePolicy.keepAll => const IconData(
      0xe877,
      fontFamily: 'MaterialIcons',
    ),
    AutoDeletePolicy.keepN => const IconData(
      0xe8b8,
      fontFamily: 'MaterialIcons',
    ),
    AutoDeletePolicy.deleteAfterWatching => const IconData(
      0xe872,
      fontFamily: 'MaterialIcons',
    ),
  };
}
