import 'package:flutter/material.dart';

import '../providers/channel_providers.dart';

/// Typed action keys for sort/filter operations emitted by
/// [ChannelSortMenu]. Using an enum avoids stringly-typed
/// switch statements in the caller.
enum ChannelSortAction {
  sortDefault,
  sortName,
  sortDateAdded,
  sortWatchTime,
  sortManual,
  done,
  reset,
  toggleDuplicates,
  groupCategory,
  groupPlaylist,

  /// Toggles visibility of individually hidden/blocked channels.
  /// Spec: FE-TV-04.
  toggleShowHidden,
}

/// Sort/reorder popup menu for the channel list.
///
/// Fires [onSelected] with a [ChannelSortAction] value.
/// The caller interprets the action and dispatches to
/// the appropriate notifier method.
class ChannelSortMenu extends StatelessWidget {
  const ChannelSortMenu({
    super.key,
    required this.state,
    required this.duplicateCount,
    required this.onSelected,
    this.hiddenChannelCount = 0,
  });

  final ChannelListState state;
  final int duplicateCount;
  final ValueChanged<ChannelSortAction> onSelected;

  /// Number of individually hidden channels.
  /// When > 0 the "Show / Hide Hidden Channels" menu item
  /// is rendered.
  final int hiddenChannelCount;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ChannelSortAction>(
      icon: Icon(state.isReorderMode ? Icons.check : Icons.sort),
      tooltip: state.isReorderMode ? 'Done reordering' : 'Sort options',
      onSelected: onSelected,
      itemBuilder: (_) => _buildItems(),
    );
  }

  List<PopupMenuEntry<ChannelSortAction>> _buildItems() {
    if (state.isReorderMode) {
      return [
        const PopupMenuItem(
          value: ChannelSortAction.done,
          child: ListTile(
            leading: Icon(Icons.check),
            title: Text('Done'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ];
    }

    final cs = state.sortMode;
    return [
      _sortItem(
        ChannelSortAction.sortDefault,
        Icons.format_list_numbered,
        'By Playlist Order',
        cs == ChannelSortMode.defaultOrder,
      ),
      _sortItem(
        ChannelSortAction.sortName,
        Icons.sort_by_alpha,
        'By Name',
        cs == ChannelSortMode.byName,
      ),
      _sortItem(
        ChannelSortAction.sortDateAdded,
        Icons.schedule,
        'By Date Added',
        cs == ChannelSortMode.byDateAdded,
      ),
      _sortItem(
        ChannelSortAction.sortWatchTime,
        Icons.history,
        'By Watch Time',
        cs == ChannelSortMode.byWatchTime,
      ),
      _sortItem(
        ChannelSortAction.sortManual,
        Icons.drag_handle,
        'Manual Reorder',
        cs == ChannelSortMode.manual,
      ),
      const PopupMenuDivider(),
      if (state.customOrderMap != null)
        const PopupMenuItem(
          value: ChannelSortAction.reset,
          child: ListTile(
            leading: Icon(Icons.restore),
            title: Text('Reset to Default'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (duplicateCount > 0)
        PopupMenuItem(
          value: ChannelSortAction.toggleDuplicates,
          child: ListTile(
            leading: Icon(
              state.hideDuplicates ? Icons.visibility : Icons.visibility_off,
            ),
            title: Text(
              state.hideDuplicates
                  ? 'Show Duplicates'
                      ' ($duplicateCount)'
                  : 'Hide Duplicates'
                      ' ($duplicateCount)',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      // ── Hidden channels toggle (FE-TV-04) ─────────────
      if (hiddenChannelCount > 0)
        PopupMenuItem(
          value: ChannelSortAction.toggleShowHidden,
          child: ListTile(
            leading: Icon(
              state.showHiddenChannels
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            title: Text(
              state.showHiddenChannels
                  ? 'Hide Hidden Channels'
                  : 'Show Hidden Channels'
                      ' ($hiddenChannelCount)',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (state.sourceNames.length > 1) ...[
        const PopupMenuDivider(),
        _sortItem(
          ChannelSortAction.groupCategory,
          Icons.category,
          'Group by Category',
          state.groupMode == ChannelGroupMode.byCategory,
        ),
        _sortItem(
          ChannelSortAction.groupPlaylist,
          Icons.playlist_play,
          'Group by Playlist',
          state.groupMode == ChannelGroupMode.byPlaylist,
        ),
      ],
    ];
  }

  PopupMenuItem<ChannelSortAction> _sortItem(
    ChannelSortAction value,
    IconData icon,
    String label,
    bool selected,
  ) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: selected ? const Icon(Icons.check, size: 18) : null,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
