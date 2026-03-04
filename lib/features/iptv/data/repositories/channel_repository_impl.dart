import 'dart:convert';

import '../../../../core/data/cache_service.dart';
import '../../../../core/data/crispy_backend.dart';
import '../../domain/entities/channel.dart';
import '../../domain/repositories/channel_repository.dart';
import '../datasources/channel_local_datasource.dart';
import '../models/channel_model.dart';

/// Concrete implementation of [ChannelRepository]
/// backed by ObjectBox via [ChannelLocalDatasource].
///
/// Strategy: parse-first on initial load -> persist to
/// ObjectBox. Subsequent loads read from ObjectBox;
/// background refresh triggered by [RefreshPlaylist]
/// use case.
class ChannelRepositoryImpl implements ChannelRepository {
  const ChannelRepositoryImpl(this._datasource, this._backend);

  final ChannelLocalDatasource _datasource;
  final CrispyBackend _backend;

  @override
  Future<List<Channel>> getChannels() async {
    final models = _datasource.getAll();
    final channels = models.map((m) => m.toDomain()).toList();
    return _sortChannels(channels);
  }

  @override
  Future<List<Channel>> getByGroup(String group) async {
    final models = _datasource.getAll(group: group);
    final channels = models.map((m) => m.toDomain()).toList();
    return _sortChannels(channels);
  }

  @override
  Future<List<String>> getGroups() async {
    return _datasource.getAllGroups();
  }

  @override
  Future<List<Channel>> search(String query) async {
    final models = _datasource.search(query);
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<List<Channel>> getFavorites() async {
    final models = _datasource.getFavorites();
    final channels = models.map((m) => m.toDomain()).toList();
    return _sortChannels(channels);
  }

  @override
  Future<Channel> toggleFavorite(String channelId) async {
    final updated = _datasource.toggleFavorite(channelId);
    if (updated == null) {
      throw StateError('Channel $channelId not found');
    }
    return updated.toDomain();
  }

  @override
  Future<Channel?> getById(String channelId) async {
    return _datasource.findById(channelId)?.toDomain();
  }

  /// Persists a batch of parsed channels.
  ///
  /// Called by the [RefreshPlaylist] use case after
  /// parsing M3U or Xtream data. Preserves existing
  /// favorite status.
  Future<void> saveChannels(List<Channel> channels, {String? sourceId}) async {
    final models =
        channels
            .map((c) => ChannelModel.fromDomain(c, sourceId: sourceId))
            .toList();
    _datasource.putAll(models);
  }

  /// Sorts channels via the Rust backend
  /// (by number ascending, nulls last, then name).
  Future<List<Channel>> _sortChannels(List<Channel> channels) async {
    if (channels.isEmpty) return channels;
    final json = jsonEncode(channels.map(channelToMap).toList());
    final sorted = await _backend.sortChannelsJson(json);
    final list = jsonDecode(sorted) as List<dynamic>;
    return list.map((m) => mapToChannel(m as Map<String, dynamic>)).toList();
  }
}
