import '../models/channel_model.dart';

/// Local datasource for channel persistence.
///
/// Currently uses in-memory storage. Will be backed by
/// ObjectBox once `flutter pub run build_runner build`
/// generates the query classes (`ChannelModel_`).
class ChannelLocalDatasource {
  ChannelLocalDatasource();

  final Map<String, ChannelModel> _store = {};

  /// Returns all channels, optionally filtered by [group].
  List<ChannelModel> getAll({String? group}) {
    if (group != null && group.isNotEmpty) {
      return _store.values.where((m) => m.group == group).toList();
    }
    return List.unmodifiable(_store.values.toList());
  }

  /// Searches channels by name (case-insensitive
  /// contains).
  List<ChannelModel> search(String query) {
    if (query.isEmpty) return getAll();
    final lower = query.toLowerCase();
    return _store.values
        .where((m) => m.name.toLowerCase().contains(lower))
        .toList();
  }

  /// Returns all favorite channels.
  List<ChannelModel> getFavorites() {
    return _store.values.where((m) => m.isFavorite).toList();
  }

  /// Finds a channel by its domain ID.
  ChannelModel? findById(String id) => _store[id];

  /// Upserts a single channel (insert or update by
  /// domain ID).
  void put(ChannelModel model) {
    final existing = _store[model.id];
    if (existing != null) {
      // Preserve favorite status across refreshes.
      model.isFavorite = existing.isFavorite;
    }
    _store[model.id] = model;
  }

  /// Bulk upsert — efficient for playlist refresh.
  void putAll(List<ChannelModel> models) {
    for (final m in models) {
      put(m);
    }
  }

  /// Toggles a channel's favorite status. Returns
  /// updated model.
  ChannelModel? toggleFavorite(String id) {
    final model = _store[id];
    if (model == null) return null;
    model.isFavorite = !model.isFavorite;
    return model;
  }

  /// Removes all channels from a specific source.
  void removeBySource(String sourceId) {
    _store.removeWhere((_, m) => m.sourceId == sourceId);
  }

  /// Removes channels from [sourceId] that are NOT in
  /// [keepIds]. Returns count of removed channels.
  int removeStaleBySource(String sourceId, Set<String> keepIds) {
    final before = _store.length;
    _store.removeWhere(
      (id, m) => m.sourceId == sourceId && !keepIds.contains(id),
    );
    return before - _store.length;
  }

  /// Returns all unique group names.
  List<String> getAllGroups() {
    final groups = <String>{};
    for (final ch in _store.values) {
      if (ch.group != null && ch.group!.isNotEmpty) {
        groups.add(ch.group!);
      }
    }
    return groups.toList()..sort();
  }

  /// Total channel count.
  int get count => _store.length;
}
