import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/crispy_spacing.dart';

/// A single track item for the picker.
class TrackItem {
  const TrackItem({required this.index, required this.label});

  final int index;
  final String label;
}

/// Bottom sheet wrapper for track pickers.
class TrackPickerSheet extends StatelessWidget {
  const TrackPickerSheet({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
            child: Row(
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: context.l10n.commonClose,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.l10n.commonClose,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Scrollable list of track items with selection.
class TrackPickerList extends StatelessWidget {
  const TrackPickerList({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<TrackItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children:
          items
              .map(
                (item) => Semantics(
                  label: item.label,
                  selected: item.index == selectedIndex,
                  button: true,
                  child: ListTile(
                    leading: Icon(
                      item.index == selectedIndex
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color:
                          item.index == selectedIndex
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white54,
                      size: 20,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color:
                            item.index == selectedIndex
                                ? Colors.white
                                : Colors.white70,
                        fontWeight:
                            item.index == selectedIndex
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    onTap: () => onSelected(item.index),
                    dense: true,
                  ),
                ),
              )
              .toList(),
    );
  }
}
