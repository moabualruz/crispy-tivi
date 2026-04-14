import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search runtime snapshot allows empty first-run runtime state', () {
    const String source = '''
{
  "title": "CrispyTivi Search Runtime",
  "version": "1",
  "query": "",
  "active_group_title": "All",
  "groups": [],
  "notes": ["Rust-owned empty Search runtime for first-run state."]
}
''';

    final SearchRuntimeSnapshot snapshot = SearchRuntimeSnapshot.fromJsonString(
      source,
    );

    expect(snapshot.activeGroupTitle, 'All');
    expect(snapshot.groups, isEmpty);
  });

  test('search runtime snapshot parses groups and results', () {
    const String source = '''
{
  "title": "CrispyTivi Search Runtime",
  "version": "1",
  "query": "",
  "active_group_title": "Live TV",
  "groups": [
    {
      "title": "Live TV",
      "summary": "Live channels and guide-linked results.",
      "selected": true,
      "results": [
        {
          "title": "Arena Live",
          "caption": "Channel 118",
          "source_label": "Live TV",
          "handoff_label": "Open channel"
        }
      ]
    },
    {
      "title": "Movies",
      "summary": "Film results and featured rails.",
      "selected": false,
      "results": [
        {
          "title": "The Last Harbor",
          "caption": "Thriller",
          "source_label": "Movies",
          "handoff_label": "Open movie"
        }
      ]
    }
  ],
  "notes": ["Asset-backed search runtime snapshot."]
}
''';

    final SearchRuntimeSnapshot snapshot = SearchRuntimeSnapshot.fromJsonString(
      source,
    );

    expect(snapshot.title, 'CrispyTivi Search Runtime');
    expect(snapshot.version, '1');
    expect(snapshot.query, '');
    expect(snapshot.activeGroupTitle, 'Live TV');
    expect(snapshot.groups.length, 2);
    expect(snapshot.groups.first.selected, isTrue);
    expect(snapshot.groups.first.results.single.handoffLabel, 'Open channel');
    expect(snapshot.groups.last.results.single.title, 'The Last Harbor');
    expect(snapshot.notes.single, 'Asset-backed search runtime snapshot.');
  });
}
