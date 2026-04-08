import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/source_filter_provider.dart';
import '../../domain/entities/vod_item.dart';
import 'vod_service_providers.dart' show cacheServiceProvider;

const kVodPageSize = 50;

@immutable
class VodPageRequest {
  const VodPageRequest({
    this.itemType,
    this.category,
    this.query,
    this.sort = 'added_desc',
    this.page = 0,
  });

  final String? itemType;
  final String? category;
  final String? query;
  final String sort;
  final int page;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VodPageRequest &&
            other.itemType == itemType &&
            other.category == category &&
            other.query == query &&
            other.sort == sort &&
            other.page == page;
  }

  @override
  int get hashCode => Object.hash(itemType, category, query, sort, page);
}

final vodCategoriesPaginatedProvider = FutureProvider.autoDispose
    .family<List<({String name, int count})>, String?>((ref, itemType) async {
      final cacheService = ref.watch(cacheServiceProvider);
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      return cacheService.getVodCategories(
        sourceIds: sourceIds,
        itemType: itemType,
      );
    });

final vodPagePaginatedProvider = FutureProvider.autoDispose
    .family<List<VodItem>, VodPageRequest>((ref, request) async {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(seconds: 30), link.close);
      ref.onDispose(timer.cancel);

      final cacheService = ref.watch(cacheServiceProvider);
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      return cacheService.getVodPage(
        sourceIds: sourceIds,
        itemType: request.itemType,
        category: request.category,
        query: request.query,
        sort: request.sort,
        offset: request.page * kVodPageSize,
        limit: kVodPageSize,
      );
    });

final vodCountPaginatedProvider = FutureProvider.autoDispose
    .family<int, VodPageRequest>((ref, request) async {
      final cacheService = ref.watch(cacheServiceProvider);
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      return cacheService.getVodCount(
        sourceIds: sourceIds,
        itemType: request.itemType,
        category: request.category,
        query: request.query,
      );
    });

final vodSearchPaginatedProvider = FutureProvider.autoDispose
    .family<List<VodItem>, ({String query, int page})>((ref, request) async {
      final cacheService = ref.watch(cacheServiceProvider);
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      return cacheService.searchVod(
        query: request.query,
        sourceIds: sourceIds,
        offset: request.page * kVodPageSize,
        limit: kVodPageSize,
      );
    });

final vodAllPaginatedProvider = FutureProvider.autoDispose
    .family<List<VodItem>, VodPageRequest>((ref, request) async {
      final cacheService = ref.watch(cacheServiceProvider);
      final sourceIds = ref.watch(effectiveSourceIdsProvider);
      final totalCount = await cacheService.getVodCount(
        sourceIds: sourceIds,
        itemType: request.itemType,
        category: request.category,
        query: request.query,
      );
      if (totalCount == 0) return const [];

      final items = <VodItem>[];
      for (var offset = 0; offset < totalCount; offset += kVodPageSize) {
        final page = await cacheService.getVodPage(
          sourceIds: sourceIds,
          itemType: request.itemType,
          category: request.category,
          query: request.query,
          sort: request.sort,
          offset: offset,
          limit: kVodPageSize,
        );
        if (page.isEmpty) break;
        items.addAll(page);
      }
      return items;
    });
