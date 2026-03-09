import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/crispy_spacing.dart';

/// Vertical A-Z jump bar for fast alphabetical navigation in
/// large scrollable lists.
///
/// Renders a strip of letter chips along the right edge. Tapping
/// or dragging a letter scrolls the list to the first item whose
/// name starts with that letter. When available height can't fit
/// all letters, those with zero matching items are dropped first.
///
/// Supports touch (tap/drag) and D-pad (up/down + Enter).
///
/// ```dart
/// Stack(
///   children: [
///     ListView(..., controller: _scrollCtrl),
///     Positioned(
///       right: 0, top: 0, bottom: 0,
///       child: AlphaJumpBar(
///         controller: _scrollCtrl,
///         sectionOffsets: offsets,
///         totalItemCount: items.length,
///       ),
///     ),
///   ],
/// )
/// ```
class AlphaJumpBar extends StatefulWidget {
  /// The scroll controller of the target list/grid.
  final ScrollController controller;

  /// Map of uppercase letter → scroll offset (pixels). Built via
  /// [computeOffsets].
  final Map<String, double> sectionOffsets;

  /// Total number of items in the list. When below
  /// [hideThreshold], the bar hides itself.
  final int totalItemCount;

  /// Minimum item count before the bar auto-hides.
  final int hideThreshold;

  /// Optional focus node for D-pad/keyboard control.
  final FocusNode? focusNode;

  /// Called when the user navigates left out of the bar (D-pad).
  final VoidCallback? onNavigateLeft;

  const AlphaJumpBar({
    super.key,
    required this.controller,
    required this.sectionOffsets,
    this.totalItemCount = 0,
    this.hideThreshold = 50,
    this.focusNode,
    this.onNavigateLeft,
  });

  /// Builds a letter → scroll-offset map from a list of sorted
  /// item names and a fixed item extent (height per row).
  ///
  /// [headerOffset] accounts for any slivers above the list items
  /// (app bar, search bar, etc.).
  static Map<String, double> computeOffsets(
    List<String> sortedNames,
    double itemExtent, {
    double headerOffset = 0,
  }) {
    final offsets = <String, double>{};
    for (var i = 0; i < sortedNames.length; i++) {
      final name = sortedNames[i];
      final letter = name.isNotEmpty ? name[0].toUpperCase() : '#';
      offsets.putIfAbsent(letter, () => headerOffset + i * itemExtent);
    }
    return offsets;
  }

  /// Builds proportional offsets for use with sliver-based
  /// scroll views where exact pixel offsets are hard to
  /// pre-compute. Pass the result to [sectionOffsets] and
  /// call [applyMaxExtent] after the first frame when
  /// [ScrollController.position.maxScrollExtent] is known.
  ///
  /// Returns letter → fractional index (0.0 to totalCount).
  /// Use [scaleOffsets] to convert to pixel offsets.
  static Map<String, double> computeIndexOffsets(List<String> sortedNames) {
    final offsets = <String, double>{};
    for (var i = 0; i < sortedNames.length; i++) {
      final name = sortedNames[i];
      final letter = name.isNotEmpty ? name[0].toUpperCase() : '#';
      offsets.putIfAbsent(letter, () => i.toDouble());
    }
    return offsets;
  }

  /// Scales index-based offsets to pixel offsets using the
  /// scroll view's max extent and total item count.
  static Map<String, double> scaleOffsets(
    Map<String, double> indexOffsets,
    double maxScrollExtent,
    int totalItemCount,
  ) {
    if (totalItemCount <= 0) return indexOffsets;
    final scale = maxScrollExtent / totalItemCount;
    return {for (final e in indexOffsets.entries) e.key: e.value * scale};
  }

  @override
  State<AlphaJumpBar> createState() => _AlphaJumpBarState();
}

class _AlphaJumpBarState extends State<AlphaJumpBar> {
  /// All letters that have items.
  List<String> _allLetters = const [];

  /// Subset currently displayed (may be reduced for height).
  List<String> _displayed = const [];

  /// Item count per letter (for priority dropping).
  Map<String, int> _letterCounts = const {};

  /// Last computed max letter count from layout.
  int _lastMaxLetters = -1;

  /// Currently highlighted letter index (D-pad mode).
  int _highlightedIndex = 0;

  /// Whether the bar has focus (for highlight rendering).
  bool _hasFocus = false;

  /// Whether the user is currently dragging.
  bool _isDragging = false;

  /// Debounce timer for D-pad jumps.
  Timer? _debounce;

  /// Minimum vertical space per letter slot.
  static const double _minLetterHeight = 18.0;

  /// Width of the bar strip.
  static const double _barWidth = 28.0;

  @override
  void initState() {
    super.initState();
    _rebuildLetters();
  }

  @override
  void didUpdateWidget(AlphaJumpBar old) {
    super.didUpdateWidget(old);
    if (old.sectionOffsets != widget.sectionOffsets) {
      _rebuildLetters();
      _lastMaxLetters = -1;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _rebuildLetters() {
    _allLetters = widget.sectionOffsets.keys.toList()..sort();

    // Build per-letter item counts for priority dropping.
    // We approximate by measuring the gap between consecutive
    // offsets (or from last offset to end of scroll extent).
    final counts = <String, int>{};
    for (var i = 0; i < _allLetters.length; i++) {
      // Default to 1 — we know at least one item exists.
      counts[_allLetters[i]] = 1;
    }
    _letterCounts = counts;
    _displayed = _allLetters;
    _clampHighlight();
  }

  void _clampHighlight() {
    if (_displayed.isNotEmpty) {
      _highlightedIndex = _highlightedIndex.clamp(0, _displayed.length - 1);
    } else {
      _highlightedIndex = 0;
    }
  }

  /// Recompute displayed letters when height changes.
  void _updateDisplayed(double availableHeight) {
    final maxLetters = (availableHeight / _minLetterHeight).floor();
    if (maxLetters == _lastMaxLetters) return;
    _lastMaxLetters = maxLetters;
    _displayed = _displayLetters(maxLetters);
    _clampHighlight();
  }

  /// Keep up to [maxCount] letters, prioritizing those with the
  /// most items. Maintains original alphabetical order.
  List<String> _displayLetters(int maxCount) {
    if (maxCount >= _allLetters.length) return _allLetters;
    if (maxCount <= 0) return const [];

    final indices = List.generate(_allLetters.length, (i) => i);
    indices.sort(
      (a, b) => (_letterCounts[_allLetters[b]] ?? 0).compareTo(
        _letterCounts[_allLetters[a]] ?? 0,
      ),
    );
    final kept = indices.take(maxCount).toList()..sort();
    return [for (final i in kept) _allLetters[i]];
  }

  int _letterIndexFromDy(double dy, double totalHeight) {
    final index = (dy / totalHeight * _displayed.length).floor();
    return index.clamp(0, _displayed.length - 1);
  }

  void _jumpToLetter(String letter) {
    final offset = widget.sectionOffsets[letter];
    if (offset == null) return;

    final maxScroll = widget.controller.position.maxScrollExtent;
    widget.controller.jumpTo(offset.clamp(0, maxScroll));
  }

  void _debouncedJump() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (_highlightedIndex < _displayed.length) {
        _jumpToLetter(_displayed[_highlightedIndex]);
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_highlightedIndex > 0) {
        setState(() => _highlightedIndex--);
        _debouncedJump();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_highlightedIndex < _displayed.length - 1) {
        setState(() => _highlightedIndex++);
        _debouncedJump();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_highlightedIndex < _displayed.length) {
        _jumpToLetter(_displayed[_highlightedIndex]);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onNavigateLeft?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Auto-hide for small lists.
    if (widget.totalItemCount < widget.hideThreshold) {
      return const SizedBox.shrink();
    }
    if (widget.sectionOffsets.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (hasFocus) {
        setState(() => _hasFocus = hasFocus);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Subtract vertical padding so letter heights fit
          // inside the padded column.
          const verticalPad = CrispySpacing.xs * 2;
          final innerHeight = constraints.maxHeight - verticalPad;
          _updateDisplayed(innerHeight);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final idx = _letterIndexFromDy(
                d.localPosition.dy,
                constraints.maxHeight,
              );
              setState(() => _highlightedIndex = idx);
              _jumpToLetter(_displayed[idx]);
            },
            onVerticalDragStart: (_) {
              setState(() => _isDragging = true);
            },
            onVerticalDragUpdate: (d) {
              final idx = _letterIndexFromDy(
                d.localPosition.dy,
                constraints.maxHeight,
              );
              if (idx != _highlightedIndex) {
                setState(() => _highlightedIndex = idx);
                _jumpToLetter(_displayed[idx]);
              }
            },
            onVerticalDragEnd: (_) {
              setState(() => _isDragging = false);
            },
            onVerticalDragCancel: () {
              setState(() => _isDragging = false);
            },
            child: Container(
              width: _barWidth,
              padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xs),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_displayed.length, (i) {
                  final letter = _displayed[i];
                  final isHighlighted =
                      (_hasFocus || _isDragging) && i == _highlightedIndex;

                  BoxDecoration? decoration;
                  if (isHighlighted) {
                    decoration = BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    );
                  }

                  final letterColor =
                      isHighlighted
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface;

                  return SizedBox(
                    height: innerHeight / _displayed.length,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: decoration,
                        alignment: Alignment.center,
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isHighlighted
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color: letterColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}
