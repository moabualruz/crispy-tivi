import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/settings/data/backup_service.dart';

/// Test backend that returns pre-canned export/import
/// results, simulating Rust output.
class _BackupTestBackend extends MemoryBackend {
  String? exportResult;
  Map<String, dynamic>? importResult;
  bool throwOnImport = false;

  @override
  Future<String> exportBackup() async => exportResult ?? '{}';

  @override
  Future<Map<String, dynamic>> importBackup(String json) async {
    if (throwOnImport) {
      throw const FormatException('Unsupported backup version');
    }
    return importResult ?? {};
  }
}

void main() {
  late _BackupTestBackend backend;
  late CacheService cache;
  late BackupService backupService;

  setUp(() {
    backend = _BackupTestBackend();
    cache = CacheService(backend);
    backupService = BackupService(cache, backend);
  });

  group('BackupService', () {
    test('exportBackup delegates to backend', () async {
      backend.exportResult = jsonEncode({
        'version': 4,
        'exportedAt': '2025-01-01T00:00:00Z',
        'profiles': [],
        'favorites': {},
        'settings': {},
        'watchHistory': [],
        'recordings': [],
      });

      final json = await backupService.exportBackup();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['version'], 4);
      expect(data['exportedAt'], isNotNull);
      expect(data['profiles'], isA<List>());
      expect(data['favorites'], isA<Map>());
      expect(data['settings'], isA<Map>());
      expect(data['watchHistory'], isA<List>());
      expect(data['recordings'], isA<List>());
    });

    test('importBackup returns summary from backend', () async {
      backend.importResult = {
        'profiles': 1,
        'favorites': 3,
        'channel_orders': 0,
        'source_access': 0,
        'settings': 2,
        'watch_history': 0,
        'recordings': 1,
        'sources': 0,
        'storage_backends': 0,
      };

      final summary = await backupService.importBackup('{}');

      expect(summary.profiles, 1);
      expect(summary.favorites, 3);
      expect(summary.settings, 2);
      expect(summary.recordings, 1);
      expect(summary.total, 7);
    });

    test('importBackup returns zero summary for empty '
        'result', () async {
      backend.importResult = {};
      final summary = await backupService.importBackup('{}');

      expect(summary.profiles, 0);
      expect(summary.favorites, 0);
      expect(summary.total, 0);
    });

    test('importBackup propagates backend exceptions', () async {
      backend.throwOnImport = true;

      expect(
        () => backupService.importBackup('{}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('export includes profiles', () async {
      backend.exportResult = jsonEncode({
        'version': 4,
        'profiles': [
          {'id': 'p1', 'name': 'Alice', 'isChild': true},
        ],
      });

      final json = await backupService.exportBackup();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final profiles = data['profiles'] as List;

      expect(profiles.length, 1);
      expect(profiles.first['name'], 'Alice');
    });

    test('export includes recordings', () async {
      backend.exportResult = jsonEncode({
        'version': 4,
        'recordings': [
          {'id': 'r1', 'channelName': 'CNN', 'isRecurring': true},
        ],
      });

      final json = await backupService.exportBackup();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final recordings = data['recordings'] as List;

      expect(recordings.length, 1);
      expect(recordings.first['channelName'], 'CNN');
      expect(recordings.first['isRecurring'], true);
    });

    test('BackupSummary toString is readable', () {
      const summary = BackupSummary(
        profiles: 2,
        favorites: 5,
        settings: 3,
        watchHistory: 10,
        recordings: 1,
      );
      expect(summary.toString(), contains('2 profiles'));
      expect(summary.total, 21);
    });

    // ── Cloud Sync Metadata ──────────────────────

    test('sync metadata round-trip', () async {
      final time = DateTime.utc(2025, 6, 15, 12, 30);
      await backupService.setLastSyncTime(time);
      final result = await backupService.getLastSyncTime();
      expect(result, time);
    });

    test('local modified time round-trip', () async {
      final time = DateTime.utc(2025, 6, 15, 14, 0);
      await backupService.setLocalModifiedTime(time);
      final result = await backupService.getLocalModifiedTime();
      expect(result, time);
    });

    test('markLocalModified sets recent time', () async {
      await backupService.markLocalModified();
      final result = await backupService.getLocalModifiedTime();
      expect(result, isNotNull);
      expect(
        result!.difference(DateTime.now().toUtc()).abs(),
        lessThan(const Duration(seconds: 5)),
      );
    });

    test('clearSyncMetadata removes all', () async {
      await backupService.setLastSyncTime(DateTime.now());
      await backupService.markLocalModified();
      await backupService.clearSyncMetadata();

      expect(await backupService.getLastSyncTime(), isNull);
      expect(await backupService.getLocalModifiedTime(), isNull);
    });

    // ── Additional sync metadata tests ────────────

    group('sync metadata edge cases', () {
      test('getLastSyncTime returns null when unset', () async {
        final result = await backupService.getLastSyncTime();
        expect(result, isNull);
      });

      test('getLocalModifiedTime returns null when unset', () async {
        final result = await backupService.getLocalModifiedTime();
        expect(result, isNull);
      });

      test('setLastSyncTime overwrites previous value', () async {
        final first = DateTime.utc(2025, 1, 1, 10, 0);
        final second = DateTime.utc(2025, 6, 15, 12, 0);

        await backupService.setLastSyncTime(first);
        await backupService.setLastSyncTime(second);

        final result = await backupService.getLastSyncTime();
        expect(result, second);
      });

      test('setLocalModifiedTime overwrites previous', () async {
        final first = DateTime.utc(2025, 1, 1, 10, 0);
        final second = DateTime.utc(2025, 6, 15, 12, 0);

        await backupService.setLocalModifiedTime(first);
        await backupService.setLocalModifiedTime(second);

        final result = await backupService.getLocalModifiedTime();
        expect(result, second);
      });

      test('clearSyncMetadata is idempotent', () async {
        // Clear when nothing is set.
        await backupService.clearSyncMetadata();
        expect(await backupService.getLastSyncTime(), isNull);
        expect(await backupService.getLocalModifiedTime(), isNull);

        // Set, clear, clear again.
        await backupService.setLastSyncTime(DateTime.utc(2025, 3, 1));
        await backupService.clearSyncMetadata();
        await backupService.clearSyncMetadata();
        expect(await backupService.getLastSyncTime(), isNull);
      });

      test('markLocalModified then clear then '
          'markLocalModified works', () async {
        await backupService.markLocalModified();
        await backupService.clearSyncMetadata();
        await backupService.markLocalModified();

        final result = await backupService.getLocalModifiedTime();
        expect(result, isNotNull);
      });

      test('setLastSyncTime stores UTC value', () async {
        // Pass a local DateTime.
        final local = DateTime(2025, 6, 15, 14, 0);
        await backupService.setLastSyncTime(local);

        final result = await backupService.getLastSyncTime();
        expect(result, isNotNull);
        expect(result!.isUtc, isTrue);
      });
    });

    // ── Import edge cases ─────────────────────────

    group('import edge cases', () {
      test('import with missing sections returns '
          'zero for absent keys', () async {
        // Backend returns only some fields.
        backend.importResult = {
          'profiles': 2,
          // favorites, settings, etc. missing
        };

        final summary = await backupService.importBackup('{}');

        expect(summary.profiles, 2);
        expect(summary.favorites, 0);
        expect(summary.channelOrders, 0);
        expect(summary.sourceAccess, 0);
        expect(summary.settings, 0);
        expect(summary.watchHistory, 0);
        expect(summary.recordings, 0);
        expect(summary.sources, 0);
        expect(summary.storageBackends, 0);
        expect(summary.total, 2);
      });

      test('import with partial sections sums correctly', () async {
        backend.importResult = {
          'favorites': 5,
          'recordings': 3,
          'storage_backends': 1,
        };

        final summary = await backupService.importBackup('{}');

        expect(summary.favorites, 5);
        expect(summary.recordings, 3);
        expect(summary.storageBackends, 1);
        expect(summary.total, 9);
      });
    });

    // ── Export edge cases ─────────────────────────

    group('export edge cases', () {
      test('export with empty database returns '
          'valid JSON', () async {
        backend.exportResult = '{}';
        final json = await backupService.exportBackup();

        expect(json, isNotEmpty);
        final data = jsonDecode(json) as Map<String, dynamic>;
        expect(data, isA<Map>());
      });

      test('export with empty lists returns valid JSON', () async {
        backend.exportResult = jsonEncode({
          'version': 4,
          'profiles': <dynamic>[],
          'favorites': <String, dynamic>{},
          'settings': <String, dynamic>{},
          'watchHistory': <dynamic>[],
          'recordings': <dynamic>[],
          'sources': <dynamic>[],
        });

        final json = await backupService.exportBackup();
        final data = jsonDecode(json) as Map<String, dynamic>;

        expect(data['profiles'], isEmpty);
        expect(data['recordings'], isEmpty);
        expect(data['sources'], isEmpty);
      });
    });

    // ── BackupSummary toString edge cases ─────────

    group('BackupSummary toString', () {
      test('returns "Nothing imported" for empty', () {
        const summary = BackupSummary();
        expect(summary.toString(), 'Nothing imported');
      });

      test('includes all non-zero fields', () {
        const summary = BackupSummary(
          profiles: 1,
          favorites: 2,
          channelOrders: 3,
          sourceAccess: 4,
          settings: 5,
          watchHistory: 6,
          recordings: 7,
          sources: 8,
          storageBackends: 9,
        );

        final str = summary.toString();
        expect(str, contains('1 profiles'));
        expect(str, contains('2 favorites'));
        expect(str, contains('3 channel orders'));
        expect(str, contains('4 source access grants'));
        expect(str, contains('5 settings'));
        expect(str, contains('6 history'));
        expect(str, contains('7 recordings'));
        expect(str, contains('8 sources'));
        expect(str, contains('9 storage backends'));
        expect(summary.total, 45);
      });
    });
  });
}
