import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';

/// Brief loading indicator displayed during player backend handoff.
///
/// Renders a semi-transparent overlay with a centered spinner when
/// [handoffInProgressProvider] is `true`. Collapses to a zero-size
/// widget otherwise.
class HandoffOverlay extends ConsumerWidget {
  const HandoffOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = ref.watch(handoffInProgressProvider);
    if (!inProgress) return const SizedBox.shrink();

    return const ColoredBox(
      color: Colors.black54,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
