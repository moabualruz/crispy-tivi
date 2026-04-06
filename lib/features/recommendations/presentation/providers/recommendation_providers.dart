import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
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
      final engine = ref.watch(recommendationEngineProvider);

      final profile = ref.watch(
        profileServiceProvider.select((s) => s.asData?.value.activeProfile),
      );
      if (profile == null) return [];

      final items = ref.watch(vodProvider.select((s) => s.items));
      final allVod = items.where((i) => i.type != VodType.episode).toList();

      final allChannels = ref.watch(_allChannelsProvider);
      final channels = allChannels.asData?.value ?? <Channel>[];

      // Computation delegated to Rust backend.
      return engine.generateAll(
        profileId: profile.id,
        maxAllowedRating: profile.maxAllowedRating,
        allVodItems: allVod,
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

/// Internal provider for all channels.
final _allChannelsProvider = FutureProvider.autoDispose<List<Channel>>((
  ref,
) async {
  final cache = ref.watch(cacheServiceProvider);
  return cache.loadChannels();
});
