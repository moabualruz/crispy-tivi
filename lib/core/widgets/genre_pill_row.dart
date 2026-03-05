import 'package:flutter/material.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';

/// Horizontally scrollable row of genre filter chips.
///
/// "All" is always the first chip and represents the unfiltered
/// state ([selectedCategory] == null). Tapping a genre chip calls
/// [onCategorySelected] with the genre name; tapping the active
/// chip again deselects it (calls with null).
///
/// Usage:
/// ```dart
/// GenrePillRow(
///   categories: movieCategories,
///   selectedCategory: selectedCategory,
///   onCategorySelected: (cat) => setState(() => selectedCategory = cat),
/// )
/// ```
class GenrePillRow extends StatelessWidget {
  const GenrePillRow({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  /// Full list of genre/category names.
  final List<String> categories;

  /// Currently selected category, or null for "All".
  final String? selectedCategory;

  /// Called when the user taps a chip.
  ///
  /// Receives null when "All" is tapped or when the active
  /// chip is tapped a second time (deselect).
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // "All" chip + one chip per genre
    final chips = <Widget>[
      _GenreChip(
        label: 'All',
        isSelected: selectedCategory == null,
        colorScheme: colorScheme,
        textTheme: textTheme,
        onTap: () => onCategorySelected(null),
      ),
      ...categories.map(
        (cat) => _GenreChip(
          label: cat,
          isSelected: selectedCategory == cat,
          colorScheme: colorScheme,
          textTheme: textTheme,
          onTap: () {
            // Tapping the active chip deselects it.
            onCategorySelected(selectedCategory == cat ? null : cat);
          },
        ),
      ),
    ];

    return SizedBox(
      height: _kPillRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: CrispySpacing.sm),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }
}

/// Height of the pill row container (chip height + vertical padding).
const double _kPillRowHeight = 44.0;

/// A single tappable genre chip.
class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest;

    final fgColor =
        isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Semantics(
      label: '$label genre filter',
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            border: Border.all(
              color:
                  isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: fgColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
