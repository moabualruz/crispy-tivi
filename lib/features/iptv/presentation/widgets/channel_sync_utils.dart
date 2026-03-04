import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../favorites/data/favorites_history_service.dart';
import '../providers/channel_providers.dart';

/// Syncs hidden groups from user settings into the
/// channel list notifier.
void syncHiddenGroups(WidgetRef ref) {
  ref
      .read(settingsNotifierProvider)
      .whenData(
        (s) => ref
            .read(channelListProvider.notifier)
            .setHiddenGroups(s.hiddenGroups),
      );
}

/// Loads the persisted channel sort mode from
/// settings and applies it.
Future<void> loadSavedSortMode(WidgetRef ref, bool Function() isMounted) async {
  final settings = ref.read(settingsNotifierProvider);
  final n =
      settings.value != null
          ? ref.read(settingsNotifierProvider.notifier)
          : null;
  if (n == null) return;
  final saved = await n.getChannelSortMode();
  if (saved != null && isMounted()) {
    final mode = ChannelSortMode.values.where((m) => m.name == saved);
    if (mode.isNotEmpty) {
      ref.read(channelListProvider.notifier).setSortMode(mode.first);
    }
  }
}

/// Persists the channel sort mode to settings.
Future<void> saveSortMode(WidgetRef ref, ChannelSortMode mode) async {
  final settings = ref.read(settingsNotifierProvider);
  final n =
      settings.value != null
          ? ref.read(settingsNotifierProvider.notifier)
          : null;
  await n?.setChannelSortMode(mode.name);
}

/// Builds a last-watched timestamp map from
/// recently watched history and pushes it to the
/// channel list notifier.
void syncLastWatched(WidgetRef ref) {
  final h = ref.read(favoritesHistoryProvider).recentlyWatched;
  if (h.isEmpty) return;
  final now = DateTime.now();
  final map = <String, DateTime>{};
  for (int i = 0; i < h.length; i++) {
    map[h[i].id] = now.subtract(Duration(minutes: i));
  }
  ref.read(channelListProvider.notifier).setLastWatchedMap(map);
}

/// Shows reset-order confirmation dialog.
void showResetOrderDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Reset Channel Order'),
          content: const Text(
            'This will restore the default channel '
            'order for this group. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(channelListProvider.notifier).resetToDefaultOrder();
              },
              child: const Text('Reset'),
            ),
          ],
        ),
  );
}
