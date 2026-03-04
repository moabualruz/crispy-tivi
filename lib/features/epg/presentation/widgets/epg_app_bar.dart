import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/category_dropdown.dart';
import '../providers/epg_providers.dart';
import 'epg_date_selector.dart' show EpgDateSelector, kEpgDateSelectorHeight;

// ── Time-slot preset constants ────────────────────────────────────────────────

/// Height of the time-slot filter preset bar (px).
const double kEpgTimePresetBarHeight = 44.0;

/// Describes a time-of-day preset for quick EPG navigation.
class EpgTimePreset {
  const EpgTimePreset({
    required this.label,
    required this.startHour,
    required this.endHour,
    required this.icon,
  });

  /// Display label shown on the chip.
  final String label;

  /// Inclusive start hour (0–23, local time).
  final int startHour;

  /// Exclusive end hour (0–23, local time); may wrap past midnight.
  final int endHour;

  /// Icon shown on the chip.
  final IconData icon;
}

/// Built-in time-slot presets.
const List<EpgTimePreset> kEpgTimePresets = [
  EpgTimePreset(
    label: 'Morning',
    startHour: 6,
    endHour: 12,
    icon: Icons.wb_sunny_outlined,
  ),
  EpgTimePreset(
    label: 'Afternoon',
    startHour: 12,
    endHour: 18,
    icon: Icons.wb_cloudy_outlined,
  ),
  EpgTimePreset(
    label: 'Evening',
    startHour: 18,
    endHour: 22,
    icon: Icons.wb_twilight,
  ),
  EpgTimePreset(
    label: 'Night',
    startHour: 22,
    endHour: 6, // wraps past midnight
    icon: Icons.nights_stay_outlined,
  ),
];

/// Builds the EPG app bar with date selector, view mode
/// toggle, group dropdown, search, jump-to-now, and
/// refresh buttons.
class EpgAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const EpgAppBar({
    required this.state,
    required this.selectedDate,
    required this.showGroupDropdown,
    required this.onDateSelected,
    required this.onWeekChanged,
    required this.onSearch,
    required this.onJumpToNow,
    required this.onRefresh,
    this.onScrollTimeBackward,
    this.onScrollTimeForward,
    this.onTimePresetSelected,
    this.selectedTimePreset,
    this.autoScrollActive = false,
    this.onToggleAutoScroll,
    super.key,
  });

  /// Current EPG state.
  final EpgState state;

  /// Currently selected date for the date selector.
  final DateTime selectedDate;

  /// Whether to show the group dropdown (mobile).
  final bool showGroupDropdown;

  /// Called when a date is selected.
  final ValueChanged<DateTime> onDateSelected;

  /// Called when the week navigation arrows are tapped.
  final ValueChanged<int> onWeekChanged;

  /// Called when the search button is tapped.
  final VoidCallback onSearch;

  /// Called when the jump-to-now button is tapped.
  final VoidCallback onJumpToNow;

  /// Called when the refresh button is tapped.
  final VoidCallback onRefresh;

  /// Called to scroll time backward in day view.
  final VoidCallback? onScrollTimeBackward;

  /// Called to scroll time forward in day view.
  final VoidCallback? onScrollTimeForward;

  /// FE-EPG-08: Called when a time-slot preset chip is tapped.
  /// Receives the [EpgTimePreset] that was selected, or null
  /// when the same chip is tapped again to deselect.
  final ValueChanged<EpgTimePreset?>? onTimePresetSelected;

  /// FE-EPG-08: Currently active time-slot preset (null = none).
  final EpgTimePreset? selectedTimePreset;

  /// FE-EPG-06: Whether auto-scroll ("Live") mode is active.
  final bool autoScrollActive;

  /// FE-EPG-06: Called when the "Live" pill button is tapped.
  final VoidCallback? onToggleAutoScroll;

  @override
  Size get preferredSize {
    final baseHeight = kToolbarHeight + kEpgDateSelectorHeight;
    // Show preset bar only in day view (it controls hour-level scroll).
    final presetBar =
        state.viewMode == EpgViewMode.day ? kEpgTimePresetBarHeight : 0.0;
    return Size.fromHeight(baseHeight + presetBar);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // FE-EPG-08: include time-preset bar height in the bottom section
    // when in day view.
    final showPresets = state.viewMode == EpgViewMode.day;
    final bottomHeight =
        kEpgDateSelectorHeight + (showPresets ? kEpgTimePresetBarHeight : 0.0);

    return AppBar(
      title: const Text('Program Guide'),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(bottomHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EpgDateSelector(
              selectedDate: selectedDate,
              viewMode: state.viewMode,
              onDateSelected: onDateSelected,
              onWeekChanged: onWeekChanged,
              onScrollTimeBackward: onScrollTimeBackward,
              onScrollTimeForward: onScrollTimeForward,
              clock: ref.watch(epgClockProvider),
            ),
            // FE-EPG-08: time-slot filter presets (day view only).
            if (showPresets)
              _EpgTimePresetBar(
                selected: selectedTimePreset,
                onSelected: onTimePresetSelected,
              ),
          ],
        ),
      ),
      actions: [
        // EPG filter toggle — IconButton provides focus/keyboard support.
        IconButton(
          icon: Icon(
            state.showEpgOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: state.showEpgOnly ? colorScheme.primary : null,
          ),
          onPressed: () => ref.read(epgProvider.notifier).toggleEpgOnly(),
          tooltip:
              state.showEpgOnly
                  ? 'Showing EPG channels only'
                  : 'Showing all channels',
        ),
        // Day/Week toggle
        _buildViewModeToggle(context, ref),
        if (showGroupDropdown && state.groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: CrispySpacing.sm),
            child: CategoryDropdown(
              categories: state.groups,
              selectedCategory: state.selectedGroup,
              label: 'Group',
              onCategorySelected: (group) {
                ref.read(epgProvider.notifier).selectGroup(group);
              },
            ),
          ),
        // FE-EPG-06: "Live" auto-scroll toggle (day view only).
        if (state.viewMode == EpgViewMode.day)
          Padding(
            padding: const EdgeInsets.only(right: CrispySpacing.xs),
            child: Semantics(
              label:
                  autoScrollActive
                      ? 'Live mode on, tap to disable'
                      : 'Live mode off, tap to enable',
              button: true,
              child: FilterChip(
                label: const Text('Live'),
                avatar: const Icon(Icons.fiber_manual_record, size: 12),
                selected: autoScrollActive,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onToggleAutoScroll?.call(),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onSearch,
          tooltip: 'Search',
        ),
        IconButton(
          icon:
              state.isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.refresh),
          onPressed: state.isLoading ? null : onRefresh,
          tooltip: 'Refresh EPG',
        ),
      ],
    );
  }

  Widget _buildViewModeToggle(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: CrispySpacing.xs),
      child: ToggleButtons(
        isSelected: [
          state.viewMode == EpgViewMode.day,
          state.viewMode == EpgViewMode.week,
        ],
        onPressed: (index) {
          final mode = index == 0 ? EpgViewMode.day : EpgViewMode.week;
          ref.read(epgProvider.notifier).setViewMode(mode);
          // The caller handles scroll-to-now via
          // the existing onJumpToNow path after
          // this callback completes.
          WidgetsBinding.instance.addPostFrameCallback((_) => onJumpToNow());
        },
        constraints: const BoxConstraints(minWidth: 60, minHeight: 32),
        borderRadius: BorderRadius.zero,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: CrispySpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.today, size: 16),
                SizedBox(width: CrispySpacing.xs),
                Text('Day'),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: CrispySpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range, size: 16),
                SizedBox(width: CrispySpacing.xs),
                Text('Week'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── FE-EPG-08: Time-slot preset bar ──────────────────────────────────────────

/// Horizontal row of ChoiceChips for quick time-of-day navigation
/// in the EPG day view.
///
/// Tapping a chip calls [onSelected] with the preset. Tapping the
/// already-selected chip deselects it (calls [onSelected] with null).
class _EpgTimePresetBar extends StatelessWidget {
  const _EpgTimePresetBar({this.selected, this.onSelected});

  final EpgTimePreset? selected;
  final ValueChanged<EpgTimePreset?>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kEpgTimePresetBarHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        itemCount: kEpgTimePresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: CrispySpacing.sm),
        itemBuilder: (context, index) {
          final preset = kEpgTimePresets[index];
          final isSelected = selected?.label == preset.label;
          return Semantics(
            label: isSelected ? '${preset.label}, selected' : preset.label,
            button: true,
            child: ChoiceChip(
              avatar: Icon(preset.icon, size: 14),
              label: Text(preset.label),
              selected: isSelected,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) {
                // Tapping selected chip deselects.
                onSelected?.call(isSelected ? null : preset);
              },
            ),
          );
        },
      ),
    );
  }
}
