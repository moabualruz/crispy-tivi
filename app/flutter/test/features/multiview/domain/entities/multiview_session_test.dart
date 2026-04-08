import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/multiview/domain/entities/active_stream.dart';
import 'package:crispy_tivi/features/multiview/domain/entities/multiview_session.dart';

void main() {
  group('MultiViewLayout', () {
    test('twoByOne has correct dimensions', () {
      expect(MultiViewLayout.twoByOne.columns, 2);
      expect(MultiViewLayout.twoByOne.rows, 1);
      expect(MultiViewLayout.twoByOne.cellCount, 2);
    });

    test('twoByTwo has correct dimensions', () {
      expect(MultiViewLayout.twoByTwo.columns, 2);
      expect(MultiViewLayout.twoByTwo.rows, 2);
      expect(MultiViewLayout.twoByTwo.cellCount, 4);
    });

    test('threeByThree has correct dimensions', () {
      expect(MultiViewLayout.threeByThree.columns, 3);
      expect(MultiViewLayout.threeByThree.rows, 3);
      expect(MultiViewLayout.threeByThree.cellCount, 9);
    });

    test('cellCount equals columns * rows for all layouts', () {
      for (final layout in MultiViewLayout.values) {
        expect(
          layout.cellCount,
          layout.columns * layout.rows,
          reason:
              '${layout.name}: '
              '${layout.columns}x${layout.rows} '
              '!= ${layout.cellCount}',
        );
      }
    });
  });

  group('ActiveStream', () {
    test('constructs with required fields', () {
      const stream = ActiveStream(
        url: 'http://example.com/stream',
        channelName: 'CNN',
      );

      expect(stream.url, 'http://example.com/stream');
      expect(stream.channelName, 'CNN');
      expect(stream.logoUrl, isNull);
      expect(stream.isMuted, isTrue);
    });

    test('copyWith overrides specified fields', () {
      const stream = ActiveStream(
        url: 'http://example.com/stream',
        channelName: 'CNN',
        isMuted: true,
      );
      final unmuted = stream.copyWith(isMuted: false);

      expect(unmuted.isMuted, isFalse);
      expect(unmuted.url, stream.url);
      expect(unmuted.channelName, stream.channelName);
    });

    test('equality is based on all fields', () {
      const a = ActiveStream(
        url: 'http://example.com/stream',
        channelName: 'CNN',
      );
      const b = ActiveStream(
        url: 'http://example.com/stream',
        channelName: 'CNN',
      );
      const c = ActiveStream(
        url: 'http://example.com/stream',
        channelName: 'BBC',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('MultiViewSession', () {
    test('default constructor uses twoByTwo layout', () {
      const session = MultiViewSession();

      expect(session.layout, MultiViewLayout.twoByTwo);
      expect(session.slots, isEmpty);
      expect(session.audioFocusIndex, 0);
    });

    test('copyWith overrides layout', () {
      const session = MultiViewSession();
      final updated = session.copyWith(layout: MultiViewLayout.threeByThree);

      expect(updated.layout, MultiViewLayout.threeByThree);
      expect(updated.slots, session.slots);
    });

    test('copyWith overrides slots', () {
      const session = MultiViewSession();
      const stream = ActiveStream(
        url: 'http://example.com/stream',
        channelName: 'CNN',
      );
      final updated = session.copyWith(slots: [stream, null, null, null]);

      expect(updated.slots.length, 4);
      expect(updated.slots[0], stream);
      expect(updated.slots[1], isNull);
    });

    test('copyWith overrides audioFocusIndex', () {
      const session = MultiViewSession(
        slots: [
          ActiveStream(url: 'http://a.com', channelName: 'A'),
          ActiveStream(url: 'http://b.com', channelName: 'B'),
        ],
      );
      final updated = session.copyWith(audioFocusIndex: 1);

      expect(updated.audioFocusIndex, 1);
    });

    test('equality is based on all props', () {
      const a = MultiViewSession(
        layout: MultiViewLayout.twoByOne,
        audioFocusIndex: 0,
      );
      const b = MultiViewSession(
        layout: MultiViewLayout.twoByOne,
        audioFocusIndex: 0,
      );
      const c = MultiViewSession(
        layout: MultiViewLayout.twoByTwo,
        audioFocusIndex: 0,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('supports null slots for empty positions', () {
      const session = MultiViewSession(
        slots: [
          ActiveStream(url: 'http://a.com', channelName: 'A'),
          null,
          null,
          ActiveStream(url: 'http://d.com', channelName: 'D'),
        ],
      );

      expect(session.slots[0], isNotNull);
      expect(session.slots[1], isNull);
      expect(session.slots[2], isNull);
      expect(session.slots[3], isNotNull);
    });
  });
}
