import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/presentation/providers/playback_progress_provider.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

// ─── Helpers ─────────────────────────────────────────────────

VodItem _makeEpisode({required String id, int? episodeNumber}) => VodItem(
  id: id,
  name: 'Episode $id',
  streamUrl: 'http://example.com/ep$id.mp4',
  type: VodType.episode,
  episodeNumber: episodeNumber,
);

void main() {
  group('Still Watching', () {
    test('kStillWatchingThreshold is 3', () {
      expect(kStillWatchingThreshold, 3);
    });

    test('StillWatchingPrompt stores next episode and count', () {
      final next = _makeEpisode(id: '42', episodeNumber: 5);
      final prompt = StillWatchingPrompt(next, 7);

      expect(prompt.next, same(next));
      expect(prompt.next.id, '42');
      expect(prompt.next.episodeNumber, 5);
      expect(prompt.count, 7);
    });

    test('StillWatchingPrompt is a CompletionEvent subtype', () {
      final next = _makeEpisode(id: '1', episodeNumber: 1);
      final prompt = StillWatchingPrompt(next, 3);

      expect(prompt, isA<CompletionEvent>());
    });

    test('NextEpisodeAvailable stores next episode', () {
      final next = _makeEpisode(id: '99', episodeNumber: 10);
      final event = NextEpisodeAvailable(next);

      expect(event.next, same(next));
      expect(event.next.id, '99');
      expect(event.next.name, 'Episode 99');
      expect(event.next.episodeNumber, 10);
      expect(event, isA<CompletionEvent>());
    });
  });
}
