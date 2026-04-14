import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/shell_models.dart';

final class SearchRuntimeSnapshot {
  const SearchRuntimeSnapshot({
    required this.title,
    required this.version,
    required this.query,
    required this.activeGroupTitle,
    required this.groups,
    required this.notes,
  });

  const SearchRuntimeSnapshot.empty()
    : title = 'CrispyTivi Search Runtime',
      version = '0',
      query = '',
      activeGroupTitle = '',
      groups = const <SearchRuntimeGroupSnapshot>[],
      notes = const <String>[];

  factory SearchRuntimeSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('search runtime must be a JSON object');
    }
    return SearchRuntimeSnapshot.fromJson(decoded);
  }

  factory SearchRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return SearchRuntimeSnapshot(
      title: _readString(json, 'title', parent: 'search_runtime'),
      version: _readString(json, 'version', parent: 'search_runtime'),
      query: _readOptionalString(json, 'query', parent: 'search_runtime'),
      activeGroupTitle: _readString(
        json,
        'active_group_title',
        parent: 'search_runtime',
      ),
      groups: _readGroups(json, 'groups'),
      notes: _readStringList(json, 'notes', parent: 'search_runtime'),
    );
  }

  final String title;
  final String version;
  final String query;
  final String activeGroupTitle;
  final List<SearchRuntimeGroupSnapshot> groups;
  final List<String> notes;
}

final class SearchRuntimeGroupSnapshot {
  const SearchRuntimeGroupSnapshot({
    required this.title,
    required this.summary,
    required this.selected,
    required this.results,
  });

  final String title;
  final String summary;
  final bool selected;
  final List<SearchRuntimeResultSnapshot> results;
}

final class SearchRuntimeResultSnapshot {
  const SearchRuntimeResultSnapshot({
    required this.title,
    required this.caption,
    required this.sourceLabel,
    required this.handoffLabel,
    this.artwork,
  });

  final String title;
  final String caption;
  final String sourceLabel;
  final String handoffLabel;
  final ArtworkSource? artwork;
}

List<SearchRuntimeGroupSnapshot> _readGroups(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  if (value.isEmpty) {
    return const <SearchRuntimeGroupSnapshot>[];
  }
  return List<SearchRuntimeGroupSnapshot>.unmodifiable(
    value.map((Object? item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$key must contain only objects');
      }
      final Object? results = item['results'];
      if (results is! List<Object?> || results.isEmpty) {
        throw FormatException('$key.results must be a non-empty array');
      }
      return SearchRuntimeGroupSnapshot(
        title: _readString(item, 'title', parent: key),
        summary: _readString(item, 'summary', parent: key),
        selected: _readBool(item, 'selected', parent: key),
        results: List<SearchRuntimeResultSnapshot>.unmodifiable(
          results.map((Object? entry) {
            if (entry is! Map<String, dynamic>) {
              throw FormatException('$key.results must contain only objects');
            }
            return SearchRuntimeResultSnapshot(
              title: _readString(entry, 'title', parent: '$key.results'),
              caption: _readString(entry, 'caption', parent: '$key.results'),
              sourceLabel: _readString(
                entry,
                'source_label',
                parent: '$key.results',
              ),
              handoffLabel: _readString(
                entry,
                'handoff_label',
                parent: '$key.results',
              ),
              artwork: _readOptionalArtworkSource(entry, 'artwork'),
            );
          }),
        ),
      );
    }),
  );
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$parent.$key must be a non-empty string');
  }
  return value;
}

String _readOptionalString(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('$parent.$key must be a string');
  }
  return value;
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! bool) {
    throw FormatException('$parent.$key must be a bool');
  }
  return value;
}

List<String> _readStringList(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<String>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! String || entry.isEmpty) {
        throw FormatException('$parent.$key must contain only strings');
      }
      return entry;
    }),
  );
}

ArtworkSource? _readOptionalArtworkSource(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  final String kind = _readString(value, 'kind', parent: key);
  final String source = _readString(value, 'value', parent: key);
  return switch (kind) {
    'asset' => ArtworkSource.asset(source),
    'network' => ArtworkSource.network(source),
    _ => throw FormatException('$key.kind must be asset or network'),
  };
}
