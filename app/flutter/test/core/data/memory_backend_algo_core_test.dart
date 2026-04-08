import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

void main() {
  group('MemoryBackendAlgoCoreMixin', () {
    late MemoryBackend backend;

    setUp(() {
      backend = MemoryBackend();
    });

    test(
      'BUG-002: detectRecordingConflict correctly identifies overlaps on the same channel',
      () async {
        final recordingsJson = '''
      [
        {
          "id": "1",
          "channel_name": "HBO",
          "start_time": "2026-03-02T10:00:00",
          "end_time": "2026-03-02T12:00:00"
        },
        {
          "id": "2",
          "channel_name": "CNN",
          "start_time": "2026-03-02T10:00:00",
          "end_time": "2026-03-02T12:00:00"
        }
      ]
      ''';

        // Test conflict on SAME channel (HBO)
        final hasConflict = await backend.detectRecordingConflict(
          recordingsJson,
          channelName: 'HBO',
          startUtcMs:
              DateTime.parse('2026-03-02T11:00:00Z').millisecondsSinceEpoch,
          endUtcMs:
              DateTime.parse('2026-03-02T13:00:00Z').millisecondsSinceEpoch,
        );
        expect(
          hasConflict,
          isTrue,
          reason: 'Overlapping time on the same channel should conflict',
        );

        // Test NO conflict on DIFFERENT channel (AMC)
        final noConflict = await backend.detectRecordingConflict(
          recordingsJson,
          channelName: 'AMC',
          startUtcMs:
              DateTime.parse('2026-03-02T11:00:00Z').millisecondsSinceEpoch,
          endUtcMs:
              DateTime.parse('2026-03-02T13:00:00Z').millisecondsSinceEpoch,
        );
        expect(
          noConflict,
          isFalse,
          reason: 'Overlapping time on a different channel should not conflict',
        );

        // Test NO conflict on SAME channel (HBO) but DIFFERENT time
        final noTimeConflict = await backend.detectRecordingConflict(
          recordingsJson,
          channelName: 'HBO',
          startUtcMs:
              DateTime.parse('2026-03-02T13:00:00Z').millisecondsSinceEpoch,
          endUtcMs:
              DateTime.parse('2026-03-02T14:00:00Z').millisecondsSinceEpoch,
        );
        expect(
          noTimeConflict,
          isFalse,
          reason: 'Different time on the same channel should not conflict',
        );
      },
    );
  });
}
