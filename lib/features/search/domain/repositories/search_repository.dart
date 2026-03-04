import '../../../../core/domain/media_source.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../entities/grouped_search_results.dart';
import '../entities/search_filter.dart';

/// Contract for the unified search operation.
abstract class SearchRepository {
  /// Searches all provided [sources] and local content
  /// for [query].
  ///
  /// Results are grouped by content type and filtered
  /// according to [filter].
  ///
  /// Throws on error.
  Future<GroupedSearchResults> search(
    String query, {
    required SearchFilter filter,
    required List<MediaSource> sources,
    List<VodItem>? vodItems,
    Map<String, List<EpgEntry>>? epgEntries,
    List<Channel>? channels,
  });
}
