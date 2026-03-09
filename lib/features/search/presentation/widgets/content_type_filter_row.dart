import 'package:flutter/material.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/search_filter.dart';

/// Horizontal row of filter chips for content type selection.
///
/// Displays toggleable chips for Channels, Movies, Series, and EPG Programs.
/// When no chips are selected, all content types are searched.
class ContentTypeFilterRow extends StatelessWidget {
  const ContentTypeFilterRow({
    super.key,
    required this.filter,
    required this.onToggle,
  });

  /// Current search filter state.
  final SearchFilter filter;

  /// Called when a content type chip is toggled.
  final void Function(SearchContentType type) onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Row(
        children: [
          _FilterChip(
            label: context.l10n.searchFilterChannels,
            icon: Icons.live_tv,
            isSelected: filter.contentTypes.contains(
              SearchContentType.channels,
            ),
            selectedColor: colorScheme.primary,
            onTap: () => onToggle(SearchContentType.channels),
            semanticLabel: 'Filter by Channels',
          ),
          const SizedBox(width: CrispySpacing.sm),
          _FilterChip(
            label: context.l10n.searchFilterMovies,
            icon: Icons.movie,
            isSelected: filter.contentTypes.contains(SearchContentType.movies),
            selectedColor: colorScheme.primary,
            onTap: () => onToggle(SearchContentType.movies),
            semanticLabel: 'Filter by Movies',
          ),
          const SizedBox(width: CrispySpacing.sm),
          _FilterChip(
            label: context.l10n.searchFilterSeries,
            icon: Icons.tv,
            isSelected: filter.contentTypes.contains(SearchContentType.series),
            selectedColor: colorScheme.primary,
            onTap: () => onToggle(SearchContentType.series),
            semanticLabel: 'Filter by Series',
          ),
          const SizedBox(width: CrispySpacing.sm),
          _FilterChip(
            label: 'Programs',
            icon: Icons.schedule,
            isSelected: filter.contentTypes.contains(SearchContentType.epg),
            selectedColor: colorScheme.primary,
            onTap: () => onToggle(SearchContentType.epg),
            semanticLabel: 'Filter by EPG Programs',
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  /// Accessibility label read by screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticLabel ?? label,
      selected: isSelected,
      button: true,
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: CrispySpacing.xs),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: selectedColor,
        checkmarkColor: colorScheme.onPrimary,
        labelStyle: TextStyle(
          color:
              isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        ),
        side: BorderSide(
          color: isSelected ? selectedColor : colorScheme.outline,
        ),
        showCheckmark: false,
      ),
    );
  }
}
