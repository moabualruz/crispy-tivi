import 'package:crispy_tivi/features/dvr/domain/entities/recording.dart';
import 'package:crispy_tivi/features/dvr/domain/utils/recording_search.dart';
import 'package:flutter_test/flutter_test.dart';

Recording _rec({
  required String id,
  required String programName,
  required String channelName,
  required DateTime startTime,
  RecordingStatus status = RecordingStatus.completed,
}) => Recording(
  id: id,
  channelName: channelName,
  programName: programName,
  startTime: startTime,
  endTime: startTime.add(const Duration(hours: 1)),
  status: status,
);

void main() {
  final base = DateTime(2024, 3, 15, 20, 30);

  final news = _rec(
    id: '1',
    programName: 'Evening News',
    channelName: 'BBC One',
    startTime: base,
  );
  final sport = _rec(
    id: '2',
    programName: 'Football Match',
    channelName: 'Sport24',
    startTime: DateTime(2024, 5, 20, 18, 0),
  );
  final movie = _rec(
    id: '3',
    programName: 'Inception',
    channelName: 'HBO',
    startTime: DateTime(2024, 3, 1, 22, 0),
  );

  final all = [news, sport, movie];

  group('filterRecordings', () {
    test('empty query returns all recordings unchanged', () {
      expect(filterRecordings(all, ''), equals(all));
    });

    test('matches by program name (case-insensitive)', () {
      final result = filterRecordings(all, 'evening');
      expect(result, equals([news]));
    });

    test('matches by channel name (case-insensitive)', () {
      final result = filterRecordings(all, 'sport24');
      expect(result, equals([sport]));
    });

    test('matches by date YYYY-MM-DD format', () {
      // sport startTime is 2024-05-20
      final result = filterRecordings(all, '2024-05-20');
      expect(result, equals([sport]));
    });

    test('partial date match works', () {
      // Both news (2024-03-15) and movie (2024-03-01) are in March 2024
      final result = filterRecordings(all, '2024-03');
      expect(result, containsAll([news, movie]));
      expect(result.length, equals(2));
    });

    test('no matches returns empty list', () {
      final result = filterRecordings(all, 'zzznomatch');
      expect(result, isEmpty);
    });

    test(
      'query is trimmed externally — whitespace in middle still matches',
      () {
        // The function does not trim; caller trims. Test as-is.
        final result = filterRecordings(all, 'Evening News');
        expect(result, equals([news]));
      },
    );

    test('uppercase query matches lowercase content', () {
      final result = filterRecordings(all, 'BBC ONE');
      expect(result, equals([news]));
    });

    test('returns empty list for empty recordings input', () {
      expect(filterRecordings([], 'news'), isEmpty);
    });

    test('does not mutate the input list', () {
      final input = List<Recording>.from(all);
      filterRecordings(input, 'news');
      expect(input, equals(all));
    });

    test('multiple fields can match the same query', () {
      // If a program is named 'BBC' and channel is 'BBC', both match.
      final dual = _rec(
        id: '99',
        programName: 'BBC Documentary',
        channelName: 'BBC Two',
        startTime: base,
      );
      final result = filterRecordings([dual], 'bbc');
      expect(result, equals([dual]));
    });
  });
}
