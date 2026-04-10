import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
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

      final channels = ref.watch(
        channelListProvider.select((state) => state.channels),
      );
      final vodItems = ref.watch(vodProvider.select((state) => state.items));
      if (channels.isEmpty && vodItems.isEmpty) return [];

      final engine = ref.watch(recommendationEngineProvider);
      return engine.generateAll(
        profileId: profile.id,
        maxAllowedRating: profile.effectiveMaxRating,
        allVodItems: vodItems,
        allChannels: channels,
      );
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
