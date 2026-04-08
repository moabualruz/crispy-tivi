import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../../core/providers/active_profile_provider.dart';
import '../../../../core/providers/source_filter_provider.dart';
import 'iptv_service_providers.dart' show cacheServiceProvider;
import '../../domain/entities/channel.dart';

const kChannelPageSize = 50;

@immutable
class ChannelPageRequest {
  const ChannelPageRequest({this.group, this.page = 0, this.sort = 'name_asc'});

  final String? group;
  final int page;
  final String sort;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelPageRequest &&
        other.group == group &&
        other.page == page &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(group, page, sort);
}

final channelGroupsPaginatedProvider =
    FutureProvider.autoDispose<List<({String name, int count})>>((ref) async {
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      final cache = ref.watch(cacheServiceProvider);
      return cache.getChannelGroups(sourceIds);
    });

final channelPagePaginatedProvider = FutureProvider.autoDispose
    .family<List<Channel>, ChannelPageRequest>((ref, request) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(seconds: 30), link.close);
      ref.onDispose(timer.cancel);

      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      final cache = ref.watch(cacheServiceProvider);

      return cache.getChannelsPage(
        sourceIds: sourceIds,
        group: request.group,
        sort: request.sort,
        offset: request.page * kChannelPageSize,
        limit: kChannelPageSize,
      );
    });

final channelCountPaginatedProvider = FutureProvider.autoDispose
    .family<int, String?>((ref, group) async {
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      final cache = ref.watch(cacheServiceProvider);
      return cache.getChannelCount(sourceIds: sourceIds, group: group);
    });

final channelIdsPaginatedProvider = FutureProvider.autoDispose
    .family<List<String>, ({String? group, String sort})>((ref, args) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(seconds: 60), link.close);
      ref.onDispose(timer.cancel);

      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      final cache = ref.watch(cacheServiceProvider);

      return cache.getChannelIdsForGroup(
        sourceIds: sourceIds,
        group: args.group,
        sort: args.sort,
      );
    });

final channelByIdPaginatedProvider = FutureProvider.autoDispose
    .family<Channel?, String>((ref, id) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(seconds: 30), link.close);
      ref.onDispose(timer.cancel);

      final cache = ref.watch(cacheServiceProvider);
      return cache.getChannelById(id);
    });

final favoriteChannelsPaginatedProvider =
    FutureProvider.autoDispose<List<Channel>>((ref) async {
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      final cache = ref.watch(cacheServiceProvider);

      return cache.getFavoriteChannels(
        sourceIds: sourceIds,
        profileId: profileId,
      );
    });

final channelSearchPaginatedProvider = FutureProvider.autoDispose
    .family<List<Channel>, ({String query, int page})>((ref, args) async {
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      final cache = ref.watch(cacheServiceProvider);

      return cache.searchChannels(
        query: args.query,
        sourceIds: sourceIds,
        offset: args.page * kChannelPageSize,
        limit: kChannelPageSize,
      );
    });
