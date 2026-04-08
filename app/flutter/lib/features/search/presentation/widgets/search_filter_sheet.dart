import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/category_dropdown.dart';
import '../../domain/entities/search_filter.dart';

// ── Sheet size constants ──────────────────────────────────────────────────────

/// Default fractional height of the filter sheet when first shown.
const double _kSheetInitialSize = 0.5;

/// Minimum fractional height of the filter sheet (collapsed).
const double _kSheetMinSize = 0.3;

/// Maximum fractional height of the filter sheet (expanded).
const double _kSheetMaxSize = 0.8;

// ── Drag handle constants ─────────────────────────────────────────────────────

/// Width of the drag handle pill at the top of the sheet.
const double _kDragHandleWidth = 40.0;

/// Height of the drag handle pill.
const double _kDragHandleHeight = 4.0;

// ── Apply button constants ────────────────────────────────────────────────────

/// Minimum height of the Apply Filters button.
const double _kApplyButtonMinHeight = 48.0;

/// Bottom sheet for advanced search filters.
///
/// Provides controls for:
/// - Category/genre selection
/// - Year range (from/to)
/// - Search in descriptions toggle
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({
    super.key,
    required this.filter,
    required this.categories,
    required this.onApply,
    required this.onClear,
  });

  /// Current filter state.
  final SearchFilter filter;

  /// Available categories for selection.
  final List<String> categories;

  /// Called when filters are applied.
  final void Function(SearchFilter filter) onApply;

  /// Called when filters are cleared.
  final VoidCallback onClear;

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late String? _category;
  late int? _yearMin;
  late int? _yearMax;
  late bool _searchInDescription;

  final _yearMinController = TextEditingController();
  final _yearMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.filter.category;
    _yearMin = widget.filter.yearMin;
    _yearMax = widget.filter.yearMax;
    _searchInDescription = widget.filter.searchInDescription;

    if (_yearMin != null) {
      _yearMinController.text = _yearMin.toString();
    }
    if (_yearMax != null) {
      _yearMaxController.text = _yearMax.toString();
    }
  }

  @override
  void dispose() {
    _yearMinController.dispose();
    _yearMaxController.dispose();
    super.dispose();
  }

  void _apply() {
    final newFilter = widget.filter.copyWith(
      category: _category,
      clearCategory: _category == null,
      yearMin: _yearMin,
      yearMax: _yearMax,
      clearYearRange: _yearMin == null && _yearMax == null,
      searchInDescription: _searchInDescription,
    );
    widget.onApply(newFilter);
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.onClear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: _kSheetInitialSize,
      minChildSize: _kSheetMinSize,
      maxChildSize: _kSheetMaxSize,
      expand: false,
      builder: (context, scrollController) {
        // S-013: Map Escape key to dismiss the sheet so TV remote Back
        // button and keyboard Escape both close it without tapping.
        return Shortcuts(
          shortcuts: {
            const SingleActivator(
              LogicalKeyboardKey.escape,
            ): VoidCallbackIntent(() => Navigator.of(context).pop()),
          },
          child: Actions(
            actions: {
              VoidCallbackIntent: CallbackAction<VoidCallbackIntent>(
                onInvoke: (intent) => intent.callback(),
              ),
            },
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(CrispyRadius.none),
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: CrispySpacing.sm),
                    width: _kDragHandleWidth,
                    height: _kDragHandleHeight,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(CrispyRadius.none),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(CrispySpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Advanced Filters',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _clear,
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(CrispySpacing.md),
                      children: [
                        // Category/Genre
                        Text('Category / Genre', style: textTheme.labelLarge),
                        const SizedBox(height: CrispySpacing.sm),
                        CategoryDropdown(
                          categories: widget.categories,
                          selectedCategory: _category,
                          label: 'All Categories',
                          onCategorySelected: (cat) {
                            setState(() => _category = cat);
                          },
                        ),

                        const SizedBox(height: CrispySpacing.lg),

                        // Year Range
                        Text('Year Range', style: textTheme.labelLarge),
                        const SizedBox(height: CrispySpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _yearMinController,
                                decoration: InputDecoration(
                                  labelText: 'From',
                                  hintText: '1900',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      CrispyRadius.none,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: CrispySpacing.md,
                                    vertical: CrispySpacing.sm,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _yearMin = int.tryParse(value);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: CrispySpacing.md),
                            const Text('–'),
                            const SizedBox(width: CrispySpacing.md),
                            Expanded(
                              child: TextField(
                                controller: _yearMaxController,
                                decoration: InputDecoration(
                                  labelText: 'To',
                                  hintText: '2026',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      CrispyRadius.none,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: CrispySpacing.md,
                                    vertical: CrispySpacing.sm,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _yearMax = int.tryParse(value);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: CrispySpacing.lg),

                        // Search in descriptions
                        SwitchListTile(
                          title: const Text('Search in descriptions'),
                          subtitle: const Text(
                            'Include content descriptions in search',
                          ),
                          value: _searchInDescription,
                          onChanged: (value) {
                            setState(() => _searchInDescription = value);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),

                  // Apply button — autofocus: true so that when the sheet
                  // opens on a TV remote, focus lands here immediately (S-013).
                  Padding(
                    padding: const EdgeInsets.all(CrispySpacing.md),
                    child: FilledButton(
                      autofocus: true,
                      onPressed: _apply,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          _kApplyButtonMinHeight,
                        ),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows the search filter sheet.
Future<void> showSearchFilterSheet({
  required BuildContext context,
  required SearchFilter filter,
  required List<String> categories,
  required void Function(SearchFilter filter) onApply,
  required VoidCallback onClear,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => SearchFilterSheet(
          filter: filter,
          categories: categories,
          onApply: onApply,
          onClear: onClear,
        ),
  );
}
