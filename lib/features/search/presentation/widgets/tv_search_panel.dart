import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../domain/entities/search_state.dart';
import '../providers/search_providers.dart';
import 'grouped_results_list.dart';

// FE-SR-08

/// Width (dp) of the on-screen keyboard panel.
const double _kKeyboardPanelWidth = 360.0;

/// Key rows for the QWERTY on-screen keyboard.
const List<List<String>> _kQwertyRows = [
  ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
  ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
  ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
];

/// Special keys shown in the last row below QWERTY.
enum _SpecialKey { space, backspace, clear, search }

/// TV two-panel search layout.
///
/// Left panel: on-screen QWERTY keyboard with D-pad navigation.
/// Right panel: live search results updated as the user types.
///
/// Focus can move from keyboard → results via D-pad right,
/// and from results → keyboard via D-pad left.
///
/// FE-SR-08: Displayed when [context.isLarge] is true (TV / 1200 dp+).
class TvSearchPanel extends ConsumerStatefulWidget {
  const TvSearchPanel({
    required this.onItemTap,
    required this.onItemFavorite,
    required this.onItemDetails,
    super.key,
  });

  final Future<void> Function(MediaItem) onItemTap;
  final void Function(MediaItem) onItemFavorite;
  final void Function(MediaItem) onItemDetails;

  @override
  ConsumerState<TvSearchPanel> createState() => _TvSearchPanelState();
}

class _TvSearchPanelState extends ConsumerState<TvSearchPanel> {
  /// Current typed query (shown in the search bar above the keyboard).
  String _query = '';

  /// Focus scope node for the keyboard panel.
  final FocusScopeNode _keyboardFocus = FocusScopeNode(debugLabel: 'tv-kbd');

  /// Focus scope node for the results panel.
  final FocusScopeNode _resultsFocus = FocusScopeNode(debugLabel: 'tv-res');

  @override
  void initState() {
    super.initState();
    // Sync with existing search state on first load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingQuery = ref.read(searchControllerProvider).query;
      if (existingQuery.isNotEmpty && mounted) {
        setState(() => _query = existingQuery);
      }
      _keyboardFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    _resultsFocus.dispose();
    super.dispose();
  }

  void _appendChar(String char) {
    setState(() => _query = _query + char.toLowerCase());
    ref.read(searchControllerProvider.notifier).search(_query);
  }

  void _handleBackspace() {
    if (_query.isEmpty) return;
    setState(() => _query = _query.substring(0, _query.length - 1));
    ref.read(searchControllerProvider.notifier).search(_query);
  }

  void _handleClear() {
    setState(() => _query = '');
    ref.read(searchControllerProvider.notifier).clearSearch();
  }

  void _handleSpecial(_SpecialKey key) {
    switch (key) {
      case _SpecialKey.space:
        _appendChar(' ');
      case _SpecialKey.backspace:
        _handleBackspace();
      case _SpecialKey.clear:
        _handleClear();
      case _SpecialKey.search:
        // Move focus to results panel.
        _resultsFocus.requestFocus();
    }
  }

  void _moveToResults() {
    _resultsFocus.requestFocus();
  }

  void _moveToKeyboard() {
    _keyboardFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left panel: on-screen keyboard ───────────────────────────────
        SizedBox(
          width: _kKeyboardPanelWidth,
          child: FocusScope(
            node: _keyboardFocus,
            child: CallbackShortcuts(
              bindings: {
                // D-pad right from keyboard moves to results.
                const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                  if (_query.isNotEmpty) _moveToResults();
                },
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Query display bar.
                  _QueryBar(query: _query, colorScheme: colorScheme),
                  const SizedBox(height: CrispySpacing.md),
                  // QWERTY grid.
                  Expanded(
                    child: _OnScreenKeyboard(
                      onChar: _appendChar,
                      onSpecial: _handleSpecial,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        VerticalDivider(
          width: 1,
          thickness: 1,
          color: colorScheme.outlineVariant,
        ),

        // ── Right panel: live results ─────────────────────────────────────
        Expanded(
          child: FocusScope(
            node: _resultsFocus,
            child: CallbackShortcuts(
              bindings: {
                // D-pad left from results moves back to keyboard.
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                  _moveToKeyboard();
                },
              },
              child: _TvResultsPanel(
                state: state,
                onItemTap: widget.onItemTap,
                onItemFavorite: widget.onItemFavorite,
                onItemDetails: widget.onItemDetails,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Query display bar ─────────────────────────────────────────────────────────

/// Styled display of the current typed query above the keyboard.
class _QueryBar extends StatelessWidget {
  const _QueryBar({required this.query, required this.colorScheme});

  final String query;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Text(
              query.isEmpty ? 'Type to search…' : query,
              style: textTheme.bodyLarge?.copyWith(
                color:
                    query.isEmpty
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Blinking cursor indicator.
          if (query.isNotEmpty)
            AnimatedOpacity(
              duration: CrispyAnimation.normal,
              opacity: 1.0,
              child: Container(
                width: 2,
                height: 20,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ── On-screen keyboard ────────────────────────────────────────────────────────

/// QWERTY on-screen keyboard with D-pad-navigable keys.
///
/// FE-SR-08: Each key is wrapped in [FocusWrapper] for TV D-pad support.
class _OnScreenKeyboard extends StatelessWidget {
  const _OnScreenKeyboard({required this.onChar, required this.onSpecial});

  final void Function(String) onChar;
  final void Function(_SpecialKey) onSpecial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // QWERTY rows.
          for (final row in _kQwertyRows) ...[
            _KeyRow(keys: row, onChar: onChar),
            const SizedBox(height: CrispySpacing.xs),
          ],
          const SizedBox(height: CrispySpacing.sm),
          // Special keys row.
          _SpecialKeyRow(onSpecial: onSpecial),
        ],
      ),
    );
  }
}

/// A horizontal row of letter keys.
class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys, required this.onChar});

  final List<String> keys;
  final void Function(String) onChar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final key in keys)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.xxs,
              ),
              child: _LetterKey(letter: key, onTap: () => onChar(key)),
            ),
          ),
      ],
    );
  }
}

/// A single letter key button.
class _LetterKey extends StatelessWidget {
  const _LetterKey({required this.letter, required this.onTap});

  final String letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.xs,
      scaleFactor: 1.2,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 28, maxWidth: 36),
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(CrispyRadius.xs),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of special action keys: Space, Backspace, Clear, Search.
class _SpecialKeyRow extends StatelessWidget {
  const _SpecialKeyRow({required this.onSpecial});

  final void Function(_SpecialKey) onSpecial;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SpecialKeyButton(
          label: 'Space',
          icon: Icons.space_bar,
          onTap: () => onSpecial(_SpecialKey.space),
          flex: 3,
        ),
        const SizedBox(width: CrispySpacing.xs),
        _SpecialKeyButton(
          label: 'Del',
          icon: Icons.backspace_outlined,
          onTap: () => onSpecial(_SpecialKey.backspace),
        ),
        const SizedBox(width: CrispySpacing.xs),
        _SpecialKeyButton(
          label: 'Clear',
          icon: Icons.clear_all,
          onTap: () => onSpecial(_SpecialKey.clear),
        ),
        const SizedBox(width: CrispySpacing.xs),
        _SpecialKeyButton(
          label: 'Results',
          icon: Icons.arrow_forward,
          onTap: () => onSpecial(_SpecialKey.search),
          isPrimary: true,
        ),
      ],
    );
  }
}

/// A single special key button (wider than a letter key).
class _SpecialKeyButton extends StatelessWidget {
  const _SpecialKeyButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.flex = 1,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int flex;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        isPrimary ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final fgColor = isPrimary ? colorScheme.onPrimary : colorScheme.onSurface;

    return Flexible(
      flex: flex,
      child: FocusWrapper(
        onSelect: onTap,
        borderRadius: CrispyRadius.xs,
        scaleFactor: 1.1,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(CrispyRadius.xs),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fgColor),
                const SizedBox(width: CrispySpacing.xxs),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Results panel ─────────────────────────────────────────────────────────────

/// Right-side results panel for TV search layout.
///
/// FE-SR-08: Shows live results with a count label and empty/loading states.
class _TvResultsPanel extends StatelessWidget {
  const _TvResultsPanel({
    required this.state,
    required this.onItemTap,
    required this.onItemFavorite,
    required this.onItemDetails,
  });

  final SearchState state;
  final Future<void> Function(MediaItem) onItemTap;
  final void Function(MediaItem) onItemFavorite;
  final void Function(MediaItem) onItemDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!state.hasQuery) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_alt_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'Use the keyboard to search',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (state.isLoading) {
      return const LoadingStateWidget();
    }

    if (state.error != null) {
      return Center(
        child: Text(
          'Error: ${state.error}',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
        ),
      );
    }

    if (state.hasNoResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: CrispySpacing.md),
            Text('No results for "${state.query}"', style: textTheme.bodyLarge),
          ],
        ),
      );
    }

    final totalCount = state.results.totalCount;
    final countLabel = totalCount == 1 ? '1 result' : '$totalCount results';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          child: Text(
            countLabel,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: GroupedResultsList(
            results: state.results,
            onItemTap: onItemTap,
            onItemFavorite: onItemFavorite,
            onItemDetails: onItemDetails,
            columns: 1,
          ),
        ),
      ],
    );
  }
}
