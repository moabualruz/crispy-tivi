import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/favorites_history_provider.dart';

// F-08: channel logo dimensions as named constants.
const double kLogoWidth = 48.0;
const double kLogoHeight = 36.0;

// ── Recently Watched tab ──────────────────────────────────────

/// Recently-watched channels tab.
///
/// FE-FAV-02: Sort dropdown above the list (Recently Added,
/// A-Z, Z-A, Content Type). Preference persisted via
/// [settingsNotifierProvider].
///
/// FE-FAV-06: Long-press activates multi-select mode for bulk
/// deletion with confirmation dialog.
///
/// Uses a 2-column grid on screens ≥ 840 dp (F-09).
class RecentlyWatchedTab extends ConsumerStatefulWidget {
  const RecentlyWatchedTab({super.key, required this.state});

  final FavoritesHistoryState state;

  @override
  ConsumerState<RecentlyWatchedTab> createState() => _RecentlyWatchedTabState();
}

class _RecentlyWatchedTabState extends ConsumerState<RecentlyWatchedTab> {
  /// FE-FAV-06: IDs of currently selected channels.
  final Set<String> _selected = {};

  /// FE-FAV-06: Whether multi-select mode is active.
  bool _isSelecting = false;

  /// FE-FAV-02: Apply sort to the channel list.
  List<Channel> _sorted(List<Channel> channels, FavoritesSort sort) {
    final list = List<Channel>.from(channels);
    switch (sort) {
      case FavoritesSort.recentlyAdded:
        break;
      case FavoritesSort.nameAsc:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case FavoritesSort.nameDesc:
        list.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case FavoritesSort.contentType:
        list.sort((a, b) {
          final ga = a.group ?? '';
          final gb = b.group ?? '';
          final cmp = ga.compareTo(gb);
          if (cmp != 0) return cmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
    return list;
  }

  void _enterSelectMode(String channelId) {
    setState(() {
      _isSelecting = true;
      _selected.add(channelId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelecting = false;
      _selected.clear();
    });
  }

  void _toggleSelection(String channelId) {
    setState(() {
      if (_selected.contains(channelId)) {
        _selected.remove(channelId);
      } else {
        _selected.add(channelId);
      }
    });
  }

  void _toggleSelectAll(List<Channel> channels) {
    setState(() {
      if (_selected.length == channels.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(channels.map((c) => c.id));
      }
    });
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'Remove from history?',
      content:
          'Remove $count ${count == 1 ? 'item' : 'items'} from '
          'your recently watched history?',
      deleteLabel: 'Remove',
    );
    if (confirmed) {
      ref
          .read(favoritesHistoryProvider.notifier)
          .removeMultipleFromHistory(Set<String>.from(_selected));
      _exitSelectMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.recentlyWatched.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history,
        title: 'Nothing watched yet',
      );
    }

    final settingsAsync = ref.watch(settingsNotifierProvider);
    final currentSort =
        settingsAsync.value?.favoritesSortOption ?? FavoritesSort.recentlyAdded;
    final sorted = _sorted(widget.state.recentlyWatched, currentSort);
    final allSelected = _selected.length == sorted.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSelecting)
          FavoritesMultiSelectBar(
            selectedCount: _selected.length,
            allSelected: allSelected,
            onSelectAll: () => _toggleSelectAll(sorted),
            onDelete: () => _confirmDeleteSelected(context),
            onCancel: _exitSelectMode,
          )
        else
          FavoritesSortDropdown(
            current: currentSort,
            onChanged: (option) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .setFavoritesSortOption(option);
            },
          ),
        Expanded(
          child: ResponsiveLayout(
            compactBody: _buildList(context, sorted, crossAxisCount: 1),
            largeBody: _buildList(context, sorted, crossAxisCount: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Channel> channels, {
    required int crossAxisCount,
  }) {
    Widget itemBuilder(BuildContext ctx, int index) {
      final channel = channels[index];
      return RecentlyWatchedItem(
        channel: channel,
        isSelecting: _isSelecting,
        isSelected: _selected.contains(channel.id),
        onPlay: () {
          ref
              .read(playbackSessionProvider.notifier)
              .startPlayback(
                streamUrl: channel.streamUrl,
                isLive: true,
                channelName: channel.name,
                channelLogoUrl: channel.logoUrl,
              );
        },
        onRemove: () {
          ref
              .read(favoritesHistoryProvider.notifier)
              .removeFromHistory(channel.id);
        },
        onLongPress: () => _enterSelectMode(channel.id),
        onToggleSelect: () => _toggleSelection(channel.id),
      );
    }

    if (crossAxisCount == 1) {
      return ListView.builder(
        padding: const EdgeInsets.all(CrispySpacing.md),
        itemCount: channels.length,
        itemBuilder: (context, index) => itemBuilder(context, index),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: CrispySpacing.sm,
        mainAxisSpacing: CrispySpacing.sm,
        childAspectRatio: 4.5,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) => itemBuilder(context, index),
    );
  }
}

// ── FE-FAV-06: Multi-select action bar ────────────────────────

/// Action bar shown when multi-select mode is active on the
/// recently-watched history tab.
class FavoritesMultiSelectBar extends StatelessWidget {
  const FavoritesMultiSelectBar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onDelete,
    required this.onCancel,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel selection',
          ),
          const SizedBox(width: CrispySpacing.xs),
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: tt.titleSmall?.copyWith(color: cs.onSurface),
            ),
          ),
          TextButton.icon(
            onPressed: onSelectAll,
            icon: Icon(
              allSelected ? Icons.deselect_outlined : Icons.select_all_outlined,
              size: 18,
            ),
            label: Text(allSelected ? 'Deselect all' : 'Select all'),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
          ),
          IconButton(
            onPressed: selectedCount > 0 ? onDelete : null,
            icon: const Icon(Icons.delete_outlined),
            tooltip:
                selectedCount > 0
                    ? 'Remove $selectedCount selected'
                    : 'Select items to remove',
            color: selectedCount > 0 ? cs.error : cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

// ── FE-FAV-02: Sort dropdown ──────────────────────────────────

/// Compact sort selector shown above a favorites / history list.
class FavoritesSortDropdown extends StatelessWidget {
  const FavoritesSortDropdown({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final FavoritesSort current;
  final ValueChanged<FavoritesSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.sort, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            'Sort:',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: CrispySpacing.sm),
          DropdownButton<FavoritesSort>(
            value: current,
            isDense: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(CrispyRadius.sm),
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
            items:
                FavoritesSort.values.map((option) {
                  return DropdownMenuItem<FavoritesSort>(
                    value: option,
                    child: Text(option.label),
                  );
                }).toList(),
            onChanged: (option) {
              if (option != null) onChanged(option);
            },
          ),
        ],
      ),
    );
  }
}

// ── F-05: Recently watched channel row ────────────────────────

/// F-05: Extracted recently-watched channel row widget.
///
/// FE-FAV-06: Supports multi-select mode via [isSelecting],
/// [isSelected], [onLongPress], and [onToggleSelect].
class RecentlyWatchedItem extends StatelessWidget {
  const RecentlyWatchedItem({
    super.key,
    required this.channel,
    required this.onPlay,
    required this.onRemove,
    required this.isSelecting,
    required this.isSelected,
    required this.onLongPress,
    required this.onToggleSelect,
  });

  final Channel channel;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final backgroundColor =
        isSelected ? cs.primaryContainer.withValues(alpha: 0.3) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      shape: const RoundedRectangleBorder(),
      color: backgroundColor,
      child: FocusWrapper(
        onSelect: isSelecting ? onToggleSelect : onPlay,
        borderRadius: CrispyRadius.none,
        child: GestureDetector(
          onLongPress: isSelecting ? null : onLongPress,
          child: ListTile(
            leading:
                isSelecting
                    ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelect(),
                      activeColor: cs.primary,
                    )
                    : SizedBox(
                      width: kLogoWidth,
                      height: kLogoHeight,
                      child: SmartImage(
                        itemId: channel.id,
                        title: channel.name,
                        imageUrl:
                            channel.logoUrl != null &&
                                    channel.logoUrl!.isNotEmpty
                                ? channel.logoUrl
                                : null,
                        imageKind: 'logo',
                        fit: BoxFit.cover,
                        icon: Icons.tv,
                      ),
                    ),
            title: Text(channel.name),
            subtitle: channel.group != null ? Text(channel.group!) : null,
            trailing:
                isSelecting
                    ? null
                    : IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.close, size: 18),
                    ),
          ),
        ),
      ),
    );
  }
}
