import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../voice_search/presentation/widgets/voice_search_button.dart';
import '../providers/vod_providers.dart';

/// Height of the search/sort bar controls.
const double _kSearchBarHeight = 40.0;

/// Icon size for the search prefix and sort icons.
const double _kSearchIconSize = 20.0;

/// Icon size for the clear (×) button inside the search field.
const double _kClearIconSize = 18.0;

/// Grid density modes for the VOD poster grid.
///
/// - [compact]: smaller cards, more per row.
/// - [standard]: default sizing.
/// - [large]: bigger cards, fewer per row.
enum VodGridDensity {
  compact,
  standard,
  large;

  /// Icon representing this density mode.
  IconData get icon => switch (this) {
    VodGridDensity.compact => Icons.view_comfy,
    VodGridDensity.standard => Icons.grid_view,
    VodGridDensity.large => Icons.view_module,
  };

  /// Human-readable label.
  String get label => switch (this) {
    VodGridDensity.compact => 'Compact',
    VodGridDensity.standard => 'Standard',
    VodGridDensity.large => 'Large',
  };

  /// Cycles to the next density mode.
  VodGridDensity get next => switch (this) {
    VodGridDensity.compact => VodGridDensity.standard,
    VodGridDensity.standard => VodGridDensity.large,
    VodGridDensity.large => VodGridDensity.compact,
  };

  /// Maximum card extent (px) for
  /// [SliverGridDelegateWithMaxCrossAxisExtent].
  double maxCardExtent(double screenWidth) => switch (this) {
    VodGridDensity.compact => _compactExtent(screenWidth),
    VodGridDensity.standard => _standardExtent(screenWidth),
    VodGridDensity.large => _largeExtent(screenWidth),
  };

  static double _compactExtent(double w) {
    if (w >= 1600) return 140;
    if (w >= 1280) return 130;
    if (w >= Breakpoints.expanded) return 120;
    return 100;
  }

  static double _standardExtent(double w) {
    if (w >= 1600) return 240;
    if (w >= 1280) return 220;
    if (w >= Breakpoints.expanded) return 200;
    return 170;
  }

  static double _largeExtent(double w) {
    if (w >= 1600) return 340;
    if (w >= 1280) return 300;
    if (w >= Breakpoints.expanded) return 260;
    return 220;
  }
}

/// Search bar + sort dropdown + density toggle + shuffle for VOD tabs.
class VodSearchSortBar extends StatelessWidget {
  const VodSearchSortBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortOption,
    required this.onSortChanged,
    this.searchController,
    this.hintText = 'Search...',
    this.gridDensity = VodGridDensity.standard,
    this.onDensityChanged,
    this.onShuffle,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VodSortOption sortOption;
  final ValueChanged<VodSortOption> onSortChanged;
  final TextEditingController? searchController;

  /// Placeholder text shown in the search field.
  final String hintText;

  /// Current grid density mode.
  final VodGridDensity gridDensity;

  /// Called when the user cycles to the next density mode.
  final ValueChanged<VodGridDensity>? onDensityChanged;

  /// Called when the user taps the shuffle button.
  /// The parent is responsible for picking a random item.
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // S-021: use LayoutBuilder to switch to a two-row layout on narrow screens
    // so the action buttons never overflow or cramp the search field.
    const double narrowBreakpoint = 480.0;

    final searchField = SizedBox(
      height: _kSearchBarHeight,
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: 'Search',
          prefixIcon: const Icon(Icons.search, size: _kSearchIconSize),
          suffixIcon:
              searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.close, size: _kClearIconSize),
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController?.clear();
                      onSearchChanged('');
                    },
                  )
                  : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: CrispySpacing.sm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        style: textTheme.bodyMedium,
      ),
    );

    // Action buttons extracted so they can be placed in either Row or Wrap.
    final actionButtons = <Widget>[
      VoiceSearchButton(
        iconSize: 20,
        onResult: (text) {
          searchController?.text = text;
          onSearchChanged(text);
        },
        onPartialResult: (text) {
          searchController?.text = text;
        },
      ),
      // Grid density toggle — cycles compact → standard → large.
      Tooltip(
        message: 'Grid density: ${gridDensity.label}',
        child: IconButton(
          icon: Icon(gridDensity.icon, size: _kSearchIconSize),
          onPressed:
              onDensityChanged != null
                  ? () => onDensityChanged!(gridDensity.next)
                  : null,
        ),
      ),
      // Shuffle / random play.
      if (onShuffle != null)
        Tooltip(
          message: 'Play random item',
          child: IconButton(
            icon: const Icon(Icons.shuffle, size: _kSearchIconSize),
            onPressed: onShuffle,
          ),
        ),
      // Sort dropdown.
      Container(
        height: _kSearchBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: DropdownButton<VodSortOption>(
          value: sortOption,
          underline: const SizedBox.shrink(),
          icon: const Icon(Icons.sort, size: _kClearIconSize),
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
          isDense: true,
          items:
              VodSortOption.values.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(opt.label, style: textTheme.bodySmall),
                );
              }).toList(),
          onChanged: (value) {
            if (value != null) {
              onSortChanged(value);
            }
          },
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.md,
        CrispySpacing.sm,
        CrispySpacing.md,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < narrowBreakpoint) {
            // Narrow layout: search field on top, action buttons wrap below.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: CrispySpacing.xs),
                Wrap(
                  spacing: CrispySpacing.xs,
                  runSpacing: CrispySpacing.xs,
                  children: actionButtons,
                ),
              ],
            );
          }
          // Wide layout: everything in a single Row.
          return Row(
            children: [Expanded(child: searchField), ...actionButtons],
          );
        },
      ),
    );
  }
}
