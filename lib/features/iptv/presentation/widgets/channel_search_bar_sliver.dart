import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';

/// Inline search bar sliver for real-time channel
/// filtering.
///
/// When [visible] is `false`, renders an invisible
/// [SliverToBoxAdapter].
class ChannelSearchBarSliver extends StatelessWidget {
  const ChannelSearchBarSliver({
    super.key,
    required this.visible,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  /// Whether the search bar is shown.
  final bool visible;

  /// Text editing controller for the field.
  final TextEditingController controller;

  /// Called on every keystroke (caller should debounce).
  final ValueChanged<String> onChanged;

  /// Called when the user taps the close icon.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.xs,
        ),
        child: SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Filter channels...',
              labelText: 'Search channels',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Close search',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: CrispySpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
