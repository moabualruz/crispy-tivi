import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/epg_service_providers.dart';
import '../../../../core/theme/crispy_spacing.dart';

/// Provider for pending EPG suggestions.
final pendingEpgSuggestionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final cache = ref.watch(cacheServiceProvider);
      return cache.getPendingEpgSuggestions();
    });

/// Modal bottom sheet showing pending EPG mapping suggestions
/// for user review. Users can accept, reject, or lock each
/// suggestion.
class EpgMappingReviewSheet extends ConsumerWidget {
  const EpgMappingReviewSheet({super.key});

  /// Show as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const EpgMappingReviewSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(pendingEpgSuggestionsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle bar ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Title ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.md,
                vertical: CrispySpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: colors.primary),
                  const SizedBox(width: CrispySpacing.sm),
                  Text(
                    'EPG Mapping Suggestions',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Divider(),
            // ── Content ──
            Expanded(
              child: suggestionsAsync.when(
                data: (suggestions) {
                  if (suggestions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: colors.primary,
                          ),
                          const SizedBox(height: CrispySpacing.md),
                          Text(
                            'No pending suggestions',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                    ),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _SuggestionTile(
                        mapping: suggestions[index],
                        onAccept: () => _accept(ref, suggestions[index]),
                        onReject: () => _reject(ref, suggestions[index]),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _accept(WidgetRef ref, Map<String, dynamic> mapping) async {
    final cache = ref.read(cacheServiceProvider);
    await cache.lockEpgMapping(mapping['channel_id'] as String);
    ref.invalidate(pendingEpgSuggestionsProvider);
  }

  Future<void> _reject(WidgetRef ref, Map<String, dynamic> mapping) async {
    final cache = ref.read(cacheServiceProvider);
    await cache.deleteEpgMapping(mapping['channel_id'] as String);
    ref.invalidate(pendingEpgSuggestionsProvider);
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.mapping,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> mapping;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final confidence = (mapping['confidence'] as num?)?.toDouble() ?? 0.0;
    final pct = (confidence * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
      child: Row(
        children: [
          // ── Confidence badge ──
          _ConfidenceBadge(confidence: confidence),
          const SizedBox(width: CrispySpacing.sm),
          // ── Channel → EPG info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mapping['channel_id'] as String? ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '→ ${mapping['epg_channel_id'] ?? ''} ($pct%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'via ${mapping['source'] ?? 'unknown'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // ── Actions ──
          IconButton(
            icon: const Icon(Icons.check),
            color: colors.primary,
            tooltip: 'Accept & lock',
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: colors.error,
            tooltip: 'Reject',
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final Color badgeColor;
    if (confidence >= 0.60) {
      badgeColor = colors.tertiary;
    } else if (confidence >= 0.50) {
      badgeColor = colors.secondary;
    } else {
      badgeColor = colors.error;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${(confidence * 100).toInt()}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
