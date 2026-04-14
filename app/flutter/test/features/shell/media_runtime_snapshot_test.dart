import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media runtime snapshot allows empty first-run runtime state', () {
    const String source = '''
{
  "title": "CrispyTivi Media Runtime",
  "version": "1",
  "active_panel": "Movies",
  "active_scope": "Featured",
  "movie_hero": {
    "kicker": "Movies",
    "title": "Add a provider to unlock movies",
    "summary": "Movie shelves stay empty until a configured provider exposes VOD.",
    "primary_action": "Open Settings",
    "secondary_action": "Add provider"
  },
  "series_hero": {
    "kicker": "Series",
    "title": "Add a provider to unlock series",
    "summary": "Series shelves stay empty until a configured provider exposes series.",
    "primary_action": "Open Settings",
    "secondary_action": "Add provider"
  },
  "movie_collections": [],
  "series_collections": [],
  "series_detail": {
    "summary_title": "Series details unavailable",
    "summary_body": "Series detail will hydrate after provider setup.",
    "handoff_label": "Browse series",
    "seasons": []
  },
  "notes": ["Rust-owned empty Media runtime for first-run state."]
}
''';

    final MediaRuntimeSnapshot snapshot = MediaRuntimeSnapshot.fromJsonString(
      source,
    );

    expect(snapshot.movieCollections, isEmpty);
    expect(snapshot.seriesCollections, isEmpty);
    expect(snapshot.seriesDetail.seasons, isEmpty);
    expect(snapshot.movieHero.title, 'Add a provider to unlock movies');
  });

  test('media runtime snapshot parses movie and series runtime state', () {
    const String source = '''
{
  "title": "CrispyTivi Media Runtime",
  "version": "1",
  "active_panel": "Movies",
  "active_scope": "Featured",
  "movie_hero": {
    "kicker": "Featured film",
    "title": "The Last Harbor",
    "summary": "Cinematic detail state.",
    "primary_action": "Play trailer",
    "secondary_action": "Add to watchlist"
  },
  "series_hero": {
    "kicker": "Series spotlight",
    "title": "Shadow Signals",
    "summary": "Season-driven browsing.",
    "primary_action": "Resume S1:E6",
    "secondary_action": "Browse episodes"
  },
  "movie_collections": [
    {
      "title": "Featured Films",
      "summary": "Featured runtime films.",
      "items": [
        {"title": "The Last Harbor", "caption": "Thriller", "rank": 1},
        {
          "title": "Glass Minute",
          "caption": "Drama",
          "rank": 2,
          "playback_source": {
            "kind": "movie",
            "source_key": "media_library",
            "content_key": "glass-minute",
            "source_label": "Media Library",
            "handoff_label": "Play movie"
          },
          "playback_stream": {
            "uri": "https://stream.crispy-tivi.test/media/glass-minute.m3u8",
            "transport": "hls",
            "live": false,
            "seekable": true,
            "resume_position_seconds": 0
          }
        }
      ]
    }
  ],
  "series_collections": [
    {
      "title": "Featured Series",
      "summary": "Featured runtime series.",
      "items": [
        {"title": "Shadow Signals", "caption": "Sci-fi drama", "rank": 1},
        {"title": "Northline", "caption": "New season", "rank": 2}
      ]
    }
  ],
  "series_detail": {
    "summary_title": "Season and episode playback",
    "summary_body": "Season choice stays above episode choice.",
    "handoff_label": "Play episode",
    "seasons": [
      {
        "label": "Season 1",
        "summary": "Episode-first season.",
        "episodes": [
          {
            "code": "S1:E1",
            "title": "Cold Open",
            "summary": "Series premiere and setup.",
            "duration_label": "45 min",
            "handoff_label": "Play episode",
            "playback_source": {
              "kind": "episode",
              "source_key": "shadow-signals",
              "content_key": "S1:E1",
              "source_label": "Shadow Signals",
              "handoff_label": "Play episode"
            },
            "playback_stream": {
              "uri": "https://stream.crispy-tivi.test/series/shadow-signals/s1e1.m3u8",
              "transport": "hls",
              "live": false,
              "seekable": true,
              "resume_position_seconds": 0
            }
          }
        ]
      }
    ]
  },
  "notes": ["Asset-backed media runtime snapshot."]
}
''';

    final MediaRuntimeSnapshot snapshot = MediaRuntimeSnapshot.fromJsonString(
      source,
    );

    expect(snapshot.title, 'CrispyTivi Media Runtime');
    expect(snapshot.version, '1');
    expect(snapshot.activePanel, 'Movies');
    expect(snapshot.activeScope, 'Featured');
    expect(snapshot.movieHero.title, 'The Last Harbor');
    expect(snapshot.seriesHero.primaryAction, 'Resume S1:E6');
    expect(snapshot.movieCollections.first.items.first.rank, 1);
    expect(
      snapshot.seriesCollections.single.items.first.caption,
      'Sci-fi drama',
    );
    expect(
      snapshot.movieCollections.first.items.last.playbackStream?.uri,
      'https://stream.crispy-tivi.test/media/glass-minute.m3u8',
    );
    expect(snapshot.seriesDetail.seasons.single.episodes.single.code, 'S1:E1');
    expect(
      snapshot.seriesDetail.seasons.single.episodes.single.playbackSource?.kind,
      'episode',
    );
    expect(snapshot.notes.single, 'Asset-backed media runtime snapshot.');
  });
}
