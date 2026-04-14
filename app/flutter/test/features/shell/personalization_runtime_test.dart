import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'personalization runtime asset snapshot parses and exposes favorites',
    () {
      final PersonalizationRuntimeSnapshot snapshot =
          PersonalizationRuntimeSnapshot.fromJsonString('''
{
  "title": "CrispyTivi Personalization Runtime",
  "version": "1",
  "startup_route": "Home",
  "continue_watching": [],
  "recently_viewed": [],
  "favorite_media_keys": ["the-last-harbor"],
  "favorite_channel_numbers": ["118"],
  "notes": ["Asset-backed personalization defaults."]
}
''');

      expect(snapshot.startupRoute, 'Home');
      expect(snapshot.isFavoriteMediaKey('the-last-harbor'), isTrue);
      expect(snapshot.favoriteChannelNumbers, <String>['118']);
    },
  );

  test(
    'recordPlayback updates continue watching and recently viewed order',
    () {
      const PersistentPlaybackEntry entry = PersistentPlaybackEntry(
        kind: PersistentPlaybackKind.movie,
        contentKey: 'the-last-harbor',
        title: 'The Last Harbor',
        caption: '01:24 / 02:11 · Resume',
        summary: 'Continue from your last movie position.',
        progressLabel: '01:24 / 02:11 · Resume',
        progressValue: 0.64,
        resumePositionSeconds: 5040,
        lastViewedAt: '2026-04-12T21:15:00Z',
        detailLines: <String>['Movie · Thriller'],
      );

      final PersonalizationRuntimeSnapshot snapshot =
          const PersonalizationRuntimeSnapshot.empty().recordPlayback(entry);

      expect(snapshot.continueWatching, hasLength(1));
      expect(snapshot.recentlyViewed, hasLength(1));
      expect(snapshot.continueWatching.single.contentKey, 'the-last-harbor');
      expect(snapshot.recentlyViewed.single.contentKey, 'the-last-harbor');
    },
  );
}
