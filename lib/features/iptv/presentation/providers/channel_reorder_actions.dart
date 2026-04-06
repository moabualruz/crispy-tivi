import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/active_profile_provider.dart';
import 'channel_providers.dart';
import 'iptv_service_providers.dart';

/// Channel reorder action extensions for [ChannelListNotifier].
///
/// Split from [channel_providers.dart] to keep each file under
/// the 300-line limit while preserving all public API.
extension ChannelReorderActions on ChannelListNotifier {
  /// Reorders a channel within the current group.
  ///
  /// Called when user drags a channel from
  /// [oldIndex] to [newIndex]. Persists the new
  /// order to the database.
  Future<void> reorderChannel(int oldIndex, int newIndex) async {
    final channels = state.filteredChannels.toList();
    if (oldIndex < 0 ||
        oldIndex >= channels.length ||
        newIndex < 0 ||
        newIndex >= channels.length) {
      return;
    }

    final channel = channels.removeAt(oldIndex);
    channels.insert(newIndex, channel);

    final profileId = ref.read(activeProfileIdProvider);
    final groupName = state.effectiveGroup ?? '';

    final channelIds = channels.map((c) => c.id).toList();
    await ref
        .read(channelRepositoryProvider)
        .saveChannelOrder(profileId, groupName, channelIds);

    final orderMap = <String, int>{};
    for (int i = 0; i < channelIds.length; i++) {
      orderMap[channelIds[i]] = i;
    }
    state = state.copyWith(customOrderMap: orderMap);
  }

  /// Resets to default sort order for the current group.
  ///
  /// Deletes any custom order and reverts to
  /// number/alphabetical sort.
  Future<void> resetToDefaultOrder() async {
    final profileId = ref.read(activeProfileIdProvider);
    final groupName = state.effectiveGroup ?? '';

    await ref
        .read(channelRepositoryProvider)
        .resetChannelOrder(profileId, groupName);

    state = state.copyWith(clearCustomOrder: true);
  }
}
