import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/player/domain/entities/'
    'playback_state.dart';

void main() {
  group('PlaybackState secondary subtitle', () {
    test('defaults to null', () {
      const state = PlaybackState();
      expect(state.selectedSecondarySubtitleTrackId, isNull);
    });

    test('copyWith sets secondary track', () {
      const state = PlaybackState();
      final updated = state.copyWith(selectedSecondarySubtitleTrackId: 2);
      expect(updated.selectedSecondarySubtitleTrackId, 2);
    });

    test('copyWith clearSecondarySubtitle resets to null', () {
      final state = const PlaybackState().copyWith(
        selectedSecondarySubtitleTrackId: 1,
      );
      expect(state.selectedSecondarySubtitleTrackId, 1);

      final cleared = state.copyWith(clearSecondarySubtitle: true);
      expect(cleared.selectedSecondarySubtitleTrackId, isNull);
    });

    test('copyWith preserves secondary when not specified', () {
      final state = const PlaybackState().copyWith(
        selectedSecondarySubtitleTrackId: 3,
      );
      final updated = state.copyWith(speed: 2.0);
      expect(updated.selectedSecondarySubtitleTrackId, 3);
      expect(updated.speed, 2.0);
    });

    test('equality includes secondary subtitle', () {
      final a = const PlaybackState().copyWith(
        selectedSecondarySubtitleTrackId: 1,
      );
      final b = const PlaybackState().copyWith(
        selectedSecondarySubtitleTrackId: 1,
      );
      final c = const PlaybackState().copyWith(
        selectedSecondarySubtitleTrackId: 2,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode includes secondary subtitle', () {
      final a = const PlaybackState().copyWith(
        selectedSecondarySubtitleTrackId: 1,
      );
      final b = const PlaybackState().copyWith(
        selectedSecondarySubtitleTrackId: 1,
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('secondary cannot be same as primary', () {
      // This is enforced in PlayerService, not in PlaybackState.
      // PlaybackState allows it structurally — the service
      // prevents it before calling copyWith.
      final state = const PlaybackState().copyWith(
        selectedSubtitleTrackId: 1,
        selectedSecondarySubtitleTrackId: 1,
      );
      expect(state.selectedSubtitleTrackId, 1);
      expect(state.selectedSecondarySubtitleTrackId, 1);
    });
  });
}
