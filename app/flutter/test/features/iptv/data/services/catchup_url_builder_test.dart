import 'dart:convert';

import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/features/iptv/data/services/'
    'catchup_url_builder.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/'
    'channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/'
    'epg_entry.dart';
import 'package:crispy_tivi/features/iptv/domain/'
    'value_objects/catchup_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCrispyBackend extends Mock implements CrispyBackend {}

void main() {
  late MockCrispyBackend mockBackend;
  late CatchupUrlBuilder builder;

  // ── Helpers ──────────────────────────────────────

  Channel makeChannel({
    String id = 'ch1',
    String name = 'Test Channel',
    String streamUrl = 'http://example.com/live/s',
    bool hasCatchup = true,
    int catchupDays = 7,
    String? catchupType,
    String? catchupSource,
  }) {
    return Channel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      hasCatchup: hasCatchup,
      catchupDays: catchupDays,
      catchupType: catchupType,
      catchupSource: catchupSource,
    );
  }

  /// Creates an EPG entry that is in the past.
  EpgEntry pastEntry({String channelId = 'ch1', String title = 'Past Show'}) {
    final now = DateTime.now().toUtc();
    return EpgEntry(
      channelId: channelId,
      title: title,
      startTime: now.subtract(const Duration(hours: 3)),
      endTime: now.subtract(const Duration(hours: 2)),
    );
  }

  /// Creates an EPG entry that is currently live.
  EpgEntry liveEntry({String channelId = 'ch1', String title = 'Live Show'}) {
    final now = DateTime.now().toUtc();
    return EpgEntry(
      channelId: channelId,
      title: title,
      startTime: now.subtract(const Duration(minutes: 30)),
      endTime: now.add(const Duration(minutes: 30)),
    );
  }

  /// Creates a future EPG entry.
  EpgEntry futureEntry({
    String channelId = 'ch1',
    String title = 'Future Show',
  }) {
    final now = DateTime.now().toUtc();
    return EpgEntry(
      channelId: channelId,
      title: title,
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 2)),
    );
  }

  setUp(() {
    mockBackend = MockCrispyBackend();
    builder = CatchupUrlBuilder(mockBackend);
  });

  // ── buildCatchup ───────────────────────────────

  group('buildCatchup', () {
    test('returns null when channel has no catchup', () async {
      final channel = makeChannel(hasCatchup: false);
      final entry = pastEntry();

      final result = await builder.buildCatchup(channel: channel, entry: entry);

      expect(result, isNull);
      verifyNever(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      );
    });

    test('returns null when entry is not past '
        '(currently live)', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = liveEntry();

      final result = await builder.buildCatchup(channel: channel, entry: entry);

      expect(result, isNull);
    });

    test('returns null when entry is in the future', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = futureEntry();

      final result = await builder.buildCatchup(channel: channel, entry: entry);

      expect(result, isNull);
    });

    test('returns null when backend returns null URL', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = pastEntry();

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => null);

      final result = await builder.buildCatchup(channel: channel, entry: entry);

      expect(result, isNull);
    });

    test('returns CatchupInfo when backend returns URL', () async {
      final channel = makeChannel(name: 'CNN', hasCatchup: true);
      final entry = pastEntry(title: 'Old News');

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => 'http://archive.com/s.ts');

      final result = await builder.buildCatchup(channel: channel, entry: entry);

      expect(result, isNotNull);
      expect(result, isA<CatchupInfo>());
      expect(result!.archiveUrl, 'http://archive.com/s.ts');
      expect(result.channelName, 'CNN');
      expect(result.programTitle, 'Old News');
      expect(result.startTime, entry.startTime);
      expect(result.endTime, entry.endTime);
    });

    test('sends correct channelJson to backend', () async {
      final channel = makeChannel(id: 'ch99', name: 'Test', hasCatchup: true);
      final entry = pastEntry();

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => 'http://x.com/archive');

      await builder.buildCatchup(channel: channel, entry: entry);

      final captured =
          verify(
                () => mockBackend.buildCatchupUrl(
                  channelJson: captureAny(named: 'channelJson'),
                  startUtc: any(named: 'startUtc'),
                  endUtc: any(named: 'endUtc'),
                ),
              ).captured.single
              as String;

      final decoded = jsonDecode(captured) as Map<String, dynamic>;
      expect(decoded['id'], 'ch99');
      expect(decoded['name'], 'Test');
    });

    test('sends correct UTC timestamps to backend', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = pastEntry();

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => 'http://x.com/a');

      await builder.buildCatchup(channel: channel, entry: entry);

      final expectedStart = entry.startTime.millisecondsSinceEpoch ~/ 1000;
      final expectedEnd = entry.endTime.millisecondsSinceEpoch ~/ 1000;

      verify(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: expectedStart,
          endUtc: expectedEnd,
        ),
      ).called(1);
    });

    test('returns null when both hasCatchup is false '
        'and entry is live', () async {
      final channel = makeChannel(hasCatchup: false);
      final entry = liveEntry();

      final result = await builder.buildCatchup(channel: channel, entry: entry);

      expect(result, isNull);
    });
  });

  // ── buildXtreamCatchup ─────────────────────────

  group('buildXtreamCatchup', () {
    test('delegates to buildCatchup and returns '
        'CatchupInfo', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = pastEntry();

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => 'http://xtream.com/ts');

      final result = await builder.buildXtreamCatchup(
        channel: channel,
        entry: entry,
        baseUrl: 'http://xtream.com',
        username: 'user',
        password: 'pass',
      );

      expect(result, isNotNull);
      expect(result!.archiveUrl, 'http://xtream.com/ts');
    });

    test('returns null when channel has no catchup', () async {
      final channel = makeChannel(hasCatchup: false);
      final entry = pastEntry();

      final result = await builder.buildXtreamCatchup(
        channel: channel,
        entry: entry,
        baseUrl: 'http://x.com',
        username: 'u',
        password: 'p',
      );

      expect(result, isNull);
    });

    test('returns null when entry is not past', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = futureEntry();

      final result = await builder.buildXtreamCatchup(
        channel: channel,
        entry: entry,
        baseUrl: 'http://x.com',
        username: 'u',
        password: 'p',
      );

      expect(result, isNull);
    });
  });

  // ── buildStalkerCatchup ────────────────────────

  group('buildStalkerCatchup', () {
    test('delegates to buildCatchup and returns '
        'CatchupInfo', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = pastEntry();

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => 'http://stalker.com/a');

      final result = await builder.buildStalkerCatchup(
        channel: channel,
        entry: entry,
        baseUrl: 'http://stalker.com',
      );

      expect(result, isNotNull);
      expect(result!.archiveUrl, 'http://stalker.com/a');
    });

    test('returns null when channel has no catchup', () async {
      final channel = makeChannel(hasCatchup: false);
      final entry = pastEntry();

      final result = await builder.buildStalkerCatchup(
        channel: channel,
        entry: entry,
        baseUrl: 'http://s.com',
      );

      expect(result, isNull);
    });

    test('returns null for live entry', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = liveEntry();

      final result = await builder.buildStalkerCatchup(
        channel: channel,
        entry: entry,
        baseUrl: 'http://s.com',
      );

      expect(result, isNull);
    });
  });

  // ── buildM3uCatchup ───────────────────────────

  group('buildM3uCatchup', () {
    test('delegates to buildCatchup and returns '
        'CatchupInfo', () async {
      final channel = makeChannel(
        hasCatchup: true,
        catchupType: 'flussonic',
        catchupSource: 'http://m3u.com/{utc}',
      );
      final entry = pastEntry();

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => 'http://m3u.com/archive');

      final result = await builder.buildM3uCatchup(
        channel: channel,
        entry: entry,
      );

      expect(result, isNotNull);
      expect(result!.archiveUrl, 'http://m3u.com/archive');
    });

    test('returns null when channel has no catchup', () async {
      final channel = makeChannel(hasCatchup: false);
      final entry = pastEntry();

      final result = await builder.buildM3uCatchup(
        channel: channel,
        entry: entry,
      );

      expect(result, isNull);
    });

    test('returns null when backend returns null', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = pastEntry();

      when(
        () => mockBackend.buildCatchupUrl(
          channelJson: any(named: 'channelJson'),
          startUtc: any(named: 'startUtc'),
          endUtc: any(named: 'endUtc'),
        ),
      ).thenAnswer((_) async => null);

      final result = await builder.buildM3uCatchup(
        channel: channel,
        entry: entry,
      );

      expect(result, isNull);
    });

    test('returns null for future entry', () async {
      final channel = makeChannel(hasCatchup: true);
      final entry = futureEntry();

      final result = await builder.buildM3uCatchup(
        channel: channel,
        entry: entry,
      );

      expect(result, isNull);
    });
  });
}
