import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../providers/epg_providers.dart';

/// Height of the EPG date-selector bar (px).
///
/// Shared between [EpgDateSelector], [EpgAppBar]
/// (`PreferredSize`), and [VirtualEpgGrid]
/// (`_headerHeight`).
const double kEpgDateSelectorHeight = 50.0;

/// Date selector for day/week modes in the EPG
/// app bar.
class EpgDateSelector extends StatelessWidget {
  const EpgDateSelector({
    required this.selectedDate,
    required this.viewMode,
    required this.onDateSelected,
    required this.onWeekChanged,
    this.onScrollTimeBackward,
    this.onScrollTimeForward,
    this.clock = DateTime.now,
    super.key,
  });

  final DateTime selectedDate;
  final EpgViewMode viewMode;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback? onScrollTimeBackward;
  final VoidCallback? onScrollTimeForward;

  /// Clock function for determining "today".
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kEpgDateSelectorHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child:
          viewMode == EpgViewMode.day
              ? _buildDaySelector(context)
              : _buildWeekSelector(context),
    );
  }

  /// Day mode: horizontal scrollable date chips.
  Widget _buildDaySelector(BuildContext context) {
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);

    // Generate next 7 days
    final dates = List.generate(7, (i) => today.add(Duration(days: i)));

    return Row(
      children: [
        if (onScrollTimeBackward != null)
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onScrollTimeBackward,
            tooltip: 'Scroll Time Backward',
          ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected =
                  date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;

              final isToday = index == 0;
              final label =
                  isToday
                      ? 'Today'
                      : '${_monthName(date.month)}'
                          ' ${date.day}';

              return Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.sm),
                child: Center(
                  child: Semantics(
                    label: isSelected ? '$label, selected' : label,
                    button: true,
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => onDateSelected(date),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (onScrollTimeForward != null)
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onScrollTimeForward,
            tooltip: 'Scroll Time Forward',
          ),
      ],
    );
  }

  /// Week mode: week range with prev/next
  /// navigation.
  Widget _buildWeekSelector(BuildContext context) {
    final weekStart = _getWeekStart(selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 6));

    // Format: "Feb 17-23" or "Feb 24 - Mar 2"
    // if spanning months
    String weekLabel;
    if (weekStart.month == weekEnd.month) {
      weekLabel =
          '${_monthName(weekStart.month)}'
          ' ${weekStart.day}'
          '–${weekEnd.day}';
    } else {
      weekLabel =
          '${_monthName(weekStart.month)}'
          ' ${weekStart.day}'
          ' – ${_monthName(weekEnd.month)}'
          ' ${weekEnd.day}';
    }

    // Check if this week contains today
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentWeek =
        !today.isBefore(weekStart) &&
        today.isBefore(weekEnd.add(const Duration(days: 1)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onWeekChanged(-1),
          tooltip: 'Previous week',
        ),
        const SizedBox(width: CrispySpacing.sm),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (isCurrentWeek)
              Text(
                'This Week',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(width: CrispySpacing.sm),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onWeekChanged(1),
          tooltip: 'Next week',
        ),
      ],
    );
  }

  DateTime _getWeekStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
