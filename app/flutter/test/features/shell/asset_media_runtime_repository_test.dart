import 'package:crispy_tivi/features/shell/data/asset_media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asset media runtime repository implements the retained interface', () {
    expect(const AssetMediaRuntimeRepository(), isA<MediaRuntimeRepository>());
  });

  test('repository loads the media runtime asset', () async {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;
    const String assetJson = '''
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
        {"title": "The Last Harbor", "caption": "Thriller", "rank": 1}
      ]
    }
  ],
  "series_collections": [
    {
      "title": "Featured Series",
      "summary": "Featured runtime series.",
      "items": [
        {"title": "Shadow Signals", "caption": "Sci-fi drama", "rank": 1}
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
            "handoff_label": "Play episode"
          }
        ]
      }
    ]
  },
  "notes": ["Asset-backed media runtime snapshot."]
}
''';

    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
      if (key == AssetMediaRuntimeRepository.assetPath) {
        return const StringCodec().encodeMessage(assetJson);
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    const AssetMediaRuntimeRepository repository =
        AssetMediaRuntimeRepository();
    final MediaRuntimeSnapshot snapshot = await repository.load();

    expect(snapshot.title, 'CrispyTivi Media Runtime');
    expect(snapshot.activePanel, 'Movies');
    expect(
      snapshot.movieCollections.single.items.single.title,
      'The Last Harbor',
    );
    expect(snapshot.seriesDetail.seasons.single.episodes.single.code, 'S1:E1');
  });
}
