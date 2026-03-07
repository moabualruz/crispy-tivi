import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/profiles/domain/utils/profile_stats.dart';

void main() {
  group('ProfileViewingStats.fromJson', () {
    test('parses full JSON response', () {
      final stats = ProfileViewingStats.fromJson({
        'total_hours_watched': 12.5,
        'top_genres': ['Movies', 'Series', 'Live TV'],
        'top_channels': ['CNN', 'HBO', 'BBC'],
        'watch_streak_days': 7,
      });

      expect(stats.totalHoursWatched, 12.5);
      expect(stats.topGenres, ['Movies', 'Series', 'Live TV']);
      expect(stats.topChannels, ['CNN', 'HBO', 'BBC']);
      expect(stats.watchStreakDays, 7);
    });

    test('handles empty fields gracefully', () {
      final stats = ProfileViewingStats.fromJson({
        'total_hours_watched': 0.0,
        'top_genres': <String>[],
        'top_channels': <String>[],
        'watch_streak_days': 0,
      });

      expect(stats.totalHoursWatched, 0.0);
      expect(stats.topGenres, isEmpty);
      expect(stats.topChannels, isEmpty);
      expect(stats.watchStreakDays, 0);
    });

    test('handles missing keys with defaults', () {
      final stats = ProfileViewingStats.fromJson({});

      expect(stats.totalHoursWatched, 0.0);
      expect(stats.topGenres, isEmpty);
      expect(stats.topChannels, isEmpty);
      expect(stats.watchStreakDays, 0);
    });

    test('handles integer total_hours_watched', () {
      final stats = ProfileViewingStats.fromJson({
        'total_hours_watched': 3,
        'top_genres': ['Movies'],
        'top_channels': ['CNN'],
        'watch_streak_days': 1,
      });

      expect(stats.totalHoursWatched, 3.0);
    });
  });
}
