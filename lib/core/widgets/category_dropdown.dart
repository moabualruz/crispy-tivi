import 'package:flutter/material.dart';

import '../../features/vod/presentation/providers/favorite_categories_provider.dart';
import '../theme/crispy_spacing.dart';

/// A searchable dropdown for selecting categories.
///
/// Replaces horizontal `FilterChip` rows for screens with
/// many categories (100+). Shows a compact button that opens
/// a searchable list in a bottom sheet.
///
/// When [favoriteCategories] is provided, favorite categories
/// are shown first in the list (after "All") with a star icon.
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.label = 'Category',
    this.favoriteCategories = const {},
    this.onToggleFavoriteCategory,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final String label;

  /// Set of category names that are favorited.
  final Set<String> favoriteCategories;

  /// Called when a category's favorite star is toggled.
  final ValueChanged<String>? onToggleFavoriteCategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayText = selectedCategory ?? 'All $label';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: () => _showCategorySheet(context),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color:
                  selectedCategory != null
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list,
                size: 18,
                color:
                    selectedCategory != null
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: CrispySpacing.sm),
              Flexible(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selectedCategory != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                    color:
                        selectedCategory != null
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CrispySpacing.xs),
              Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (ctx) => _CategorySearchSheet(
            categories: categories,
            selectedCategory: selectedCategory,
            label: label,
            favoriteCategories: favoriteCategories,
            onToggleFavoriteCategory: onToggleFavoriteCategory,
            onSelected: (cat) {
              onCategorySelected(cat);
              Navigator.pop(ctx);
            },
          ),
    );
  }
}

class _CategorySearchSheet extends StatefulWidget {
  const _CategorySearchSheet({
    required this.categories,
    required this.selectedCategory,
    required this.label,
    required this.onSelected,
    required this.favoriteCategories,
    required this.onToggleFavoriteCategory,
  });

  final List<String> categories;
  final String? selectedCategory;
  final String label;
  final ValueChanged<String?> onSelected;
  final Set<String> favoriteCategories;
  final ValueChanged<String>? onToggleFavoriteCategory;

  @override
  State<_CategorySearchSheet> createState() => _CategorySearchSheetState();
}

class _CategorySearchSheetState extends State<_CategorySearchSheet> {
  final _searchController = TextEditingController();
  late List<String> _filtered;
  late Set<String> _localFavs;

  @override
  void initState() {
    super.initState();
    _localFavs = {...widget.favoriteCategories};
    _filtered = sortCategoriesWithFavorites(widget.categories, _localFavs);
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      final base =
          query.isEmpty
              ? widget.categories
              : widget.categories
                  .where((c) => c.toLowerCase().contains(query))
                  .toList();
      _filtered = sortCategoriesWithFavorites(base, _localFavs);
    });
  }

  void _toggleFav(String cat) {
    setState(() {
      if (_localFavs.contains(cat)) {
        _localFavs.remove(cat);
      } else {
        _localFavs.add(cat);
      }
      _filtered = sortCategoriesWithFavorites(
        _searchController.text.isEmpty
            ? widget.categories
            : widget.categories
                .where(
                  (c) => c.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ),
                )
                .toList(),
        _localFavs,
      );
    });
    widget.onToggleFavoriteCategory?.call(cat);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.md,
                vertical: CrispySpacing.xs,
              ),
              child: Text(
                'Select ${widget.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories\u2026',
                  labelText: 'Search categories',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                autofocus: true,
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),
            // Category list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length + 1,
                itemBuilder: (ctx, index) {
                  if (index == 0) {
                    final isSelected = widget.selectedCategory == null;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color:
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        'All'
                        ' (${widget.categories.length})',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                      ),
                      onTap: () => widget.onSelected(null),
                    );
                  }
                  final cat = _filtered[index - 1];
                  final isSelected = widget.selectedCategory == cat;
                  final isFav = _localFavs.contains(cat);
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color:
                          isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                    ),
                    title: Row(
                      children: [
                        if (isFav) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: CrispySpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing:
                        widget.onToggleFavoriteCategory != null
                            ? IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color:
                                    isFav
                                        ? Colors.amber
                                        : colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              onPressed: () => _toggleFav(cat),
                              tooltip:
                                  isFav
                                      ? 'Remove from '
                                          'favorite '
                                          'categories'
                                      : 'Add to '
                                          'favorite '
                                          'categories',
                            )
                            : null,
                    onTap: () => widget.onSelected(cat),
                    onLongPress:
                        widget.onToggleFavoriteCategory != null
                            ? () => _toggleFav(cat)
                            : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
