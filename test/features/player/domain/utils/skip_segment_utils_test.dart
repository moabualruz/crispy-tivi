import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/domain/utils/skip_segment_utils.dart';

void main() {
  const s1 = SkipSegment(
    start: Duration(seconds: 0),
    end: Duration(seconds: 90),
  );
  const s2 = SkipSegment(
    start: Duration(minutes: 5),
    end: Duration(minutes: 6),
  );
  const s3 = SkipSegment(
    start: Duration(minutes: 80),
    end: Duration(minutes: 85),
  );

  group('segmentLabel', () {
    test('single segment returns Skip Intro', () {
      expect(segmentLabel(s1, [s1]), 'Skip Intro');
    });

    test('first of multiple returns Skip Intro', () {
      expect(segmentLabel(s1, [s1, s2, s3]), 'Skip Intro');
    });

    test('last of multiple returns Skip Outro / Credits', () {
      expect(segmentLabel(s3, [s1, s2, s3]), 'Skip Outro / Credits');
    });

    test('middle segment returns Skip Recap', () {
      expect(segmentLabel(s2, [s1, s2, s3]), 'Skip Recap');
    });

    test('first-of-two returns Skip Intro', () {
      expect(segmentLabel(s1, [s1, s3]), 'Skip Intro');
    });

    test('last-of-two returns Skip Outro / Credits', () {
      expect(segmentLabel(s3, [s1, s3]), 'Skip Outro / Credits');
    });
  });
}
