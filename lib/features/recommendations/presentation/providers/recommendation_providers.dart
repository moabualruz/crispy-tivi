import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recommendation.dart';
import 'recommendation_service_providers.dart';

/// Provider for the recommendation engine.
final recommendationEngineProvider = Provider<RecommendationEngine>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final backend = ref.read(crispyBackendProvider);
  return RecommendationEngine(cache, backend);
});

/// All recommendation sections for the active
/// profile.
final recommendationSectionsProvider =
    FutureProvider.autoDispose<List<RecommendationSection>>((ref) async {
      final profile = ref.watch(
        profileServiceProvider.select((s) => s.asData?.value.activeProfile),
      );
      if (profile == null) return [];

      // TODO(perf): Rebuild recommendations from paginated/channel-specific
      // queries instead of bulk-loading the full channel and VOD catalogs.
      debugPrint(
        'Recommendations: skipping bulk preload until paginated inputs land',
      );
      return const [];
    });

/// Top picks section only.
final topPicksProvider = Provider<List<Recommendation>>((ref) {
  final sections = ref.watch(recommendationSectionsProvider);
  final data = sections.asData?.value ?? [];

  final topPicks =
      data
          .where((s) => s.reasonType == RecommendationReasonType.topPick)
          .toList();

  if (topPicks.isEmpty) return [];
  return topPicks.first.items;
});

/// VOD-only recommendation sections.
final vodRecommendationsProvider = Provider<List<RecommendationSection>>((ref) {
  final sections = ref.watch(recommendationSectionsProvider);
  final data = sections.asData?.value ?? [];

  return data.where((s) {
    return s.items.any(
      (i) => i.mediaType == 'movie' || i.mediaType == 'series',
    );
  }).toList();
});

/// Whether any recommendations are available.
final hasRecommendationsProvider = Provider<bool>((ref) {
  return ref.watch(
    recommendationSectionsProvider.select(
      (s) => s.asData?.value.any((sec) => sec.items.isNotEmpty) ?? false,
    ),
  );
});
