import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../domain/entities/vod_item.dart';

// FE-VODS-06-DETAILS: Multi-source picker.

/// A single stream source derived from a [VodItem].
///
/// In a full multi-source setup the data layer would return a list of
/// [VodSource] for a given title (e.g., one per Xtream server). For
/// now each [VodItem] represents exactly one source; the picker is
/// revealed only when the caller passes > 1 source.
@immutable
class VodSource {
  const VodSource({
    required this.label,
    required this.streamUrl,
    this.quality,
    this.health = SourceHealth.good,
  });

  /// Server/playlist label (e.g., "Server 1 — HD").
  final String label;

  /// Direct stream URL for this source.
  final String streamUrl;

  /// Quality badge label ("HD", "FHD", "4K") — null means unknown.
  final String? quality;

  /// Health indicator (default: [SourceHealth.good]).
  final SourceHealth health;

  /// Build a [VodSource] from a [VodItem].
  ///
  /// Pass [quality] from the caller (computed via the backend) to avoid
  /// needing direct Rust FFI access inside the factory.
  factory VodSource.fromVodItem(
    VodItem item, {
    String? sourceName,
    String? quality,
  }) {
    final label =
        sourceName ??
        (item.sourceId != null ? 'Server ${item.sourceId}' : 'Default');
    return VodSource(label: label, streamUrl: item.streamUrl, quality: quality);
  }
}

/// Stream health status.
enum SourceHealth {
  good, // green
  degraded, // yellow
  offline, // red
}

/// Notifier tracking the active source URL for a given VOD item.
///
/// Keyed by item ID. Defaults to [null] (uses the item's own stream URL).
class _ActiveSourceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Updates the active source URL.
  void setUrl(String? url) => state = url;
}

/// Provider tracking the active source URL for a given VOD item.
///
/// Keyed by item ID. Defaults to [null] (the item's own stream URL).
///
/// Usage:
/// ```dart
/// final active = ref.watch(activeSourceProvider('itemId'));
/// ```
final activeSourceProvider =
    NotifierProvider.family<_ActiveSourceNotifier, String?, String>(
      (arg) => _ActiveSourceNotifier(),
    );

/// "Sources" section in the VOD detail screen.
///
/// Renders a card per source showing:
/// - Server label
/// - Quality badge (HD / FHD / 4K)
/// - Health dot (green / yellow / red — stubbed to green)
/// - Highlight on the currently active source.
///
/// Hidden when [sources] has ≤ 1 entry.
///
/// The caller is responsible for building the [sources] list from
/// [VodItem] alternatives. In the V1 implementation we build a single
/// source from the item itself; the real multi-source path lands when
/// the data layer surfaces multiple streams per title.
class VodSourcePicker extends ConsumerWidget {
  const VodSourcePicker({
    super.key,
    required this.itemId,
    required this.sources,
    required this.onSourceSelected,
  });

  final String itemId;
  final List<VodSource> sources;
  final void Function(VodSource) onSourceSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide when there is only one source (or none).
    if (sources.length <= 1) return const SizedBox.shrink();

    final activeUrl = ref.watch(activeSourceProvider(itemId));
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CrispySpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
          child: Row(
            children: [
              Icon(Icons.source_rounded, size: 18, color: cs.primary),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                'Sources',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
          child: Wrap(
            spacing: CrispySpacing.sm,
            runSpacing: CrispySpacing.sm,
            children:
                sources.map((source) {
                  final isActive =
                      activeUrl != null
                          ? source.streamUrl == activeUrl
                          : source == sources.first;
                  return _SourceChip(
                    source: source,
                    isActive: isActive,
                    cs: cs,
                    textTheme: textTheme,
                    onTap: () {
                      ref
                          .read(activeSourceProvider(itemId).notifier)
                          .setUrl(source.streamUrl);
                      onSourceSelected(source);
                    },
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}

/// A single source chip.
class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.source,
    required this.isActive,
    required this.cs,
    required this.textTheme,
    required this.onTap,
  });

  final VodSource source;
  final bool isActive;
  final ColorScheme cs;
  final TextTheme textTheme;
  final VoidCallback onTap;

  Color get _healthColor {
    switch (source.health) {
      case SourceHealth.good:
        return CrispyColors.statusSuccess;
      case SourceHealth.degraded:
        return CrispyColors.statusWarning;
      case SourceHealth.offline:
        return CrispyColors.statusError;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.tv,
      scaleFactor: 1.05,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.sm,
            vertical: CrispySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isActive ? cs.primaryContainer : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(CrispyRadius.tv),
            border: Border.all(
              color: isActive ? cs.primary : cs.outline.withValues(alpha: 0.4),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Health dot.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _healthColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: CrispySpacing.xs),

              // Server label.
              Text(
                source.label,
                style: textTheme.labelMedium?.copyWith(
                  color: isActive ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),

              // Quality badge.
              if (source.quality != null) ...[
                const SizedBox(width: CrispySpacing.xs),
                _QualityBadge(
                  label: source.quality!,
                  isActive: isActive,
                  cs: cs,
                  textTheme: textTheme,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact quality badge ("HD", "FHD", "4K").
class _QualityBadge extends StatelessWidget {
  const _QualityBadge({
    required this.label,
    required this.isActive,
    required this.cs,
    required this.textTheme,
  });

  final String label;
  final bool isActive;
  final ColorScheme cs;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xxs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color:
            isActive
                ? cs.primary.withValues(alpha: 0.25)
                : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(CrispyRadius.tvSm),
        border: Border.all(
          color:
              isActive
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}
