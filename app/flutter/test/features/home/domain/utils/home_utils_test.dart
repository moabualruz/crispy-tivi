import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/home/domain/utils/home_utils.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';

void main() {
  group('dynamicSectionLabel', () {
    group('continue_watching', () {
      test('returns fallback when count is zero', () {
        expect(
          dynamicSectionLabel(
            type: 'continue_watching',
            fallback: 'Continue Watching',
            count: 0,
          ),
          'Continue Watching',
        );
      });

      test('returns fallback when count is negative', () {
        expect(
          dynamicSectionLabel(
            type: 'continue_watching',
            fallback: 'Continue Watching',
            count: -1,
          ),
          'Continue Watching',
        );
      });

      test('returns singular badge for count 1', () {
        expect(
          dynamicSectionLabel(
            type: 'continue_watching',
            fallback: 'Continue Watching',
            count: 1,
          ),
          'Continue Watching · 1 item',
        );
      });

      test('returns plural badge for count > 1', () {
        expect(
          dynamicSectionLabel(
            type: 'continue_watching',
            fallback: 'Continue Watching',
            count: 3,
          ),
          'Continue Watching · 3 items',
        );
      });
    });

    group('recently_added', () {
      test('returns fallback when items is null', () {
        expect(
          dynamicSectionLabel(type: 'recently_added', fallback: 'Latest Added'),
          'Latest Added',
        );
      });

      test('returns fallback when items is empty', () {
        expect(
          dynamicSectionLabel(
            type: 'recently_added',
            fallback: 'Latest Added',
            items: const [],
          ),
          'Latest Added',
        );
      });

      test('returns fallback when no items added this week', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 10));
        final items = [
          VodItem(
            id: '1',
            name: 'Old Movie',
            streamUrl: 'http://x.com/1.mkv',
            type: VodType.movie,
            addedAt: oldDate,
          ),
        ];
        expect(
          dynamicSectionLabel(
            type: 'recently_added',
            fallback: 'Latest Added',
            items: items,
          ),
          'Latest Added',
        );
      });

      test('returns "Added this week" label when recent items exist', () {
        final recentDate = DateTime.now().subtract(const Duration(days: 2));
        final items = [
          VodItem(
            id: '1',
            name: 'New Movie',
            streamUrl: 'http://x.com/1.mkv',
            type: VodType.movie,
            addedAt: recentDate,
          ),
          VodItem(
            id: '2',
            name: 'Another New Movie',
            streamUrl: 'http://x.com/2.mkv',
            type: VodType.movie,
            addedAt: recentDate,
          ),
        ];
        expect(
          dynamicSectionLabel(
            type: 'recently_added',
            fallback: 'Latest Added',
            items: items,
          ),
          'Added this week · 2 new',
        );
      });

      test('counts only recent items, ignores old ones', () {
        final recentDate = DateTime.now().subtract(const Duration(days: 1));
        final oldDate = DateTime.now().subtract(const Duration(days: 14));
        final items = [
          VodItem(
            id: '1',
            name: 'New',
            streamUrl: 'http://x.com/1.mkv',
            type: VodType.movie,
            addedAt: recentDate,
          ),
          VodItem(
            id: '2',
            name: 'Old',
            streamUrl: 'http://x.com/2.mkv',
            type: VodType.movie,
            addedAt: oldDate,
          ),
        ];
        expect(
          dynamicSectionLabel(
            type: 'recently_added',
            fallback: 'Latest Added',
            items: items,
          ),
          'Added this week · 1 new',
        );
      });

      test('returns fallback when addedAt is null on all items', () {
        final items = [
          const VodItem(
            id: '1',
            name: 'No Date',
            streamUrl: 'http://x.com/1.mkv',
            type: VodType.movie,
          ),
        ];
        expect(
          dynamicSectionLabel(
            type: 'recently_added',
            fallback: 'Latest Added',
            items: items,
          ),
          'Latest Added',
        );
      });
    });

    group('default / unknown type', () {
      test('returns fallback for unknown type', () {
        expect(
          dynamicSectionLabel(type: 'recommendations', fallback: 'For You'),
          'For You',
        );
      });

      test('returns empty string fallback by default', () {
        expect(dynamicSectionLabel(type: 'unknown'), '');
      });
    });
  });
}
