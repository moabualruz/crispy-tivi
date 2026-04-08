import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/crispy_radius.dart';

/// A frosted-glass bottom sheet with blur and translucent background.
///
/// Use via [GlassmorphicSheet.show] on compact/mobile breakpoints for
/// lightweight detail views. For full-featured detail screens with
/// player integration (VOD details, series details), use standard
/// route navigation instead.
///
/// ```dart
/// GlassmorphicSheet.show(
///   context: context,
///   builder: (scrollController) => ChannelInfoContent(
///     channel: channel,
///     scrollController: scrollController,
///   ),
/// );
/// ```
class GlassmorphicSheet extends StatelessWidget {
  /// Creates a glassmorphic sheet wrapper.
  const GlassmorphicSheet({
    super.key,
    required this.builder,
    this.initialChildSize = 0.6,
    this.minChildSize = 0.3,
    this.maxChildSize = 0.9,
  });

  /// Builder that receives a [ScrollController] for the sheet content.
  final Widget Function(ScrollController scrollController) builder;

  /// Initial height fraction of the screen. Defaults to 0.6.
  final double initialChildSize;

  /// Minimum height fraction when dragged down. Defaults to 0.3.
  final double minChildSize;

  /// Maximum height fraction when dragged up. Defaults to 0.9.
  final double maxChildSize;

  /// Show the glassmorphic sheet as a modal bottom sheet.
  ///
  /// Returns `null` if dismissed by drag or back gesture.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(ScrollController scrollController) builder,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => GlassmorphicSheet(
            builder: builder,
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(CrispyRadius.lg),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.85),
            borderRadius: borderRadius,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(child: builder(scrollController)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
