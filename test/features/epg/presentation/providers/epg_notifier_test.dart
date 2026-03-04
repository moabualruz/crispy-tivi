import 'package:crispy_tivi/features/epg/'
    'presentation/providers/epg_providers.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/'
    'domain/entities/epg_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Helpers ─────────────────────────────────────

  DateTime utc(int y, int m, int d, [int h = 0, int min = 0]) =>
      DateTime.utc(y, m, d, h, min);

  Channel ch(String id) =>
      Channel(id: id, name: 'Ch $id', streamUrl: 'http://s/$id');

  EpgEntry makeEntry(String channelId, String title) => EpgEntry(
    channelId: channelId,
    title: title,
    startTime: utc(2026, 2, 22, 10),
    endTime: utc(2026, 2, 22, 11),
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  EpgNotifier notifier() => container.read(epgProvider.notifier);

  EpgState state() => container.read(epgProvider);

  // ── loadData ────────────────────────────────────

  group('loadData', () {
    test('populates channels, entries, focusedTime', () {
      final channels = [ch('1'), ch('2')];
      final entries = <String, List<EpgEntry>>{
        '1': [makeEntry('1', 'Show A')],
      };

      notifier().loadData(channels: channels, entries: entries);

      final s = state();
      expect(s.channels, channels);
      expect(s.entries, entries);
      expect(s.focusedTime, isNotNull);
      expect(s.isLoading, isFalse);
    });

    test('stores epgOverrides when provided', () {
      notifier().loadData(
        channels: [ch('1')],
        entries: {},
        epgOverrides: {'ch1': 'mapped'},
      );
      expect(state().epgOverrides, {'ch1': 'mapped'});
    });
  });

  // ── setEpgOverrides ─────────────────────────────

  test('setEpgOverrides updates override map', () {
    notifier().setEpgOverrides({'a': 'b'});
    expect(state().epgOverrides, {'a': 'b'});
  });

  // ── setFocusedTime ──────────────────────────────

  test('setFocusedTime updates focused time', () {
    final t = utc(2026, 2, 22, 14);
    notifier().setFocusedTime(t);
    expect(state().focusedTime, t);
  });

  // ── selectChannel ───────────────────────────────

  test('selectChannel updates selectedChannel', () {
    notifier().selectChannel('ch5');
    expect(state().selectedChannel, 'ch5');
  });

  // ── selectEntry ─────────────────────────────────

  group('selectEntry', () {
    test('sets selected entry', () {
      final e = makeEntry('ch1', 'Test');
      notifier().selectEntry(e);
      expect(state().selectedEntry, e);
    });

    test('null clears selected entry', () {
      notifier().selectEntry(makeEntry('ch1', 'X'));
      notifier().selectEntry(null);
      expect(state().selectedEntry, isNull);
    });
  });

  // ── selectGroup ─────────────────────────────────

  group('selectGroup', () {
    test('sets group filter', () {
      notifier().selectGroup('Sports');
      expect(state().selectedGroup, 'Sports');
    });

    test('null clears group', () {
      notifier().selectGroup('Sports');
      notifier().selectGroup(null);
      expect(state().selectedGroup, isNull);
    });
  });

  // ── setViewMode ─────────────────────────────────

  test('setViewMode toggles view', () {
    expect(state().viewMode, EpgViewMode.day);
    notifier().setViewMode(EpgViewMode.week);
    expect(state().viewMode, EpgViewMode.week);
  });

  // ── setLoading ──────────────────────────────────

  test('setLoading sets loading and clears error', () {
    notifier().setError('oops');
    notifier().setLoading();
    expect(state().isLoading, isTrue);
    expect(state().error, isNull);
  });

  // ── setError ────────────────────────────────────

  test('setError sets error and clears loading', () {
    notifier().setLoading();
    notifier().setError('boom');
    expect(state().isLoading, isFalse);
    expect(state().error, 'boom');
  });

  // ── setFetchResult / clearFetchMessage ──────────

  group('fetch result messages', () {
    test('setFetchResult stores message and success', () {
      notifier().setFetchResult('Loaded 100 entries');
      expect(state().lastFetchMessage, 'Loaded 100 entries');
      expect(state().lastFetchSuccess, isTrue);
    });

    test('setFetchResult with failure', () {
      notifier().setFetchResult('Timeout', success: false);
      expect(state().lastFetchMessage, 'Timeout');
      expect(state().lastFetchSuccess, isFalse);
    });

    test('clearFetchMessage clears message', () {
      notifier().setFetchResult('ok');
      notifier().clearFetchMessage();
      expect(state().lastFetchMessage, isNull);
      expect(state().lastFetchSuccess, isNull);
    });
  });

  // ── toggleEpgOnly ───────────────────────────────

  group('toggleEpgOnly', () {
    test('toggles from true to false', () {
      expect(state().showEpgOnly, isTrue);
      notifier().toggleEpgOnly();
      expect(state().showEpgOnly, isFalse);
    });

    test('toggles from false to true', () {
      notifier().toggleEpgOnly(); // true → false
      notifier().toggleEpgOnly(); // false → true
      expect(state().showEpgOnly, isTrue);
    });
  });
}
