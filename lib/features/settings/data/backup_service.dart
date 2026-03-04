import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants.dart';
import '../../../core/data/app_directories.dart';
import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';

/// Handles exporting and importing application
/// data as JSON.
///
/// Export and import are delegated to the Rust
/// [CrispyBackend] which handles all domain-
/// specific serialisation (profiles, favorites,
/// settings, watch history, recordings, storage
/// backends, etc.).
class BackupService {
  BackupService(this._cache, this._backend);

  final CacheService _cache;
  final CrispyBackend _backend;

  // ── Export ─────────────────────────────────────

  /// Creates a complete backup as a JSON string.
  ///
  /// Delegates to Rust backend which exports:
  /// channels, VOD items, EPG entries, profiles,
  /// favorites, settings, channel orders, source
  /// access, recordings, storage backends.
  Future<String> exportBackup() async {
    return _backend.exportBackup();
  }

  // ── Import ────────────────────────────────────

  /// Imports data from a JSON backup string.
  ///
  /// Delegates to Rust backend which returns a
  /// summary map with counts per entity type.
  Future<BackupSummary> importBackup(String jsonString) async {
    final result = await _backend.importBackup(jsonString);
    return BackupSummary(
      profiles: result['profiles'] as int? ?? 0,
      favorites: result['favorites'] as int? ?? 0,
      channelOrders: result['channel_orders'] as int? ?? 0,
      sourceAccess: result['source_access'] as int? ?? 0,
      settings: result['settings'] as int? ?? 0,
      watchHistory: result['watch_history'] as int? ?? 0,
      recordings: result['recordings'] as int? ?? 0,
      sources: result['sources'] as int? ?? 0,
      storageBackends: result['storage_backends'] as int? ?? 0,
    );
  }

  // ── File-Based Export/Import ───────────────────

  /// Exports backup to a file and shares it.
  Future<String?> exportToFile() async {
    final json = await exportBackup();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'crispy_tivi_backup_$timestamp.json';

    final file = File('${AppDirectories.backups}/$fileName');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'CrispyTivi Backup'),
    );

    return file.path;
  }

  /// Exports backup to a user-selected location.
  Future<String?> saveToFile() async {
    final json = await exportBackup();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'crispy_tivi_backup_$timestamp.json';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(json),
    );

    return result;
  }

  /// Imports backup from a user-selected file.
  Future<BackupSummary?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Backup File',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    String content;

    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      throw Exception('Could not read backup file');
    }

    return importBackup(content);
  }

  // ── Cloud Sync Metadata ───────────────────────

  /// Gets the last sync timestamp.
  Future<DateTime?> getLastSyncTime() async {
    final value = await _cache.getSetting(kSyncLastTimeKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Sets the last sync timestamp.
  Future<void> setLastSyncTime(DateTime time) async {
    await _cache.setSetting(kSyncLastTimeKey, time.toUtc().toIso8601String());
  }

  /// Gets the local data modification timestamp.
  Future<DateTime?> getLocalModifiedTime() async {
    final value = await _cache.getSetting(kSyncLocalModifiedTimeKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Sets the local data modification timestamp.
  Future<void> setLocalModifiedTime(DateTime time) async {
    await _cache.setSetting(
      kSyncLocalModifiedTimeKey,
      time.toUtc().toIso8601String(),
    );
  }

  /// Updates local modification time to now.
  Future<void> markLocalModified() async {
    await setLocalModifiedTime(DateTime.now().toUtc());
  }

  /// Clears all sync metadata.
  Future<void> clearSyncMetadata() async {
    await _cache.removeSetting(kSyncLastTimeKey);
    await _cache.removeSetting(kSyncLocalModifiedTimeKey);
  }
}

/// Summary of imported backup data.
class BackupSummary {
  const BackupSummary({
    this.profiles = 0,
    this.favorites = 0,
    this.channelOrders = 0,
    this.sourceAccess = 0,
    this.settings = 0,
    this.watchHistory = 0,
    this.recordings = 0,
    this.sources = 0,
    this.storageBackends = 0,
  });

  final int profiles;
  final int favorites;
  final int channelOrders;
  final int sourceAccess;
  final int settings;
  final int watchHistory;
  final int recordings;
  final int sources;
  final int storageBackends;

  int get total =>
      profiles +
      favorites +
      channelOrders +
      sourceAccess +
      settings +
      watchHistory +
      recordings +
      sources +
      storageBackends;

  @override
  String toString() {
    final parts = <String>[];
    if (profiles > 0) {
      parts.add('$profiles profiles');
    }
    if (favorites > 0) {
      parts.add('$favorites favorites');
    }
    if (channelOrders > 0) {
      parts.add('$channelOrders channel orders');
    }
    if (sourceAccess > 0) {
      parts.add('$sourceAccess source access grants');
    }
    if (settings > 0) {
      parts.add('$settings settings');
    }
    if (watchHistory > 0) {
      parts.add('$watchHistory history');
    }
    if (recordings > 0) {
      parts.add('$recordings recordings');
    }
    if (sources > 0) {
      parts.add('$sources sources');
    }
    if (storageBackends > 0) {
      parts.add('$storageBackends storage backends');
    }
    return parts.isEmpty ? 'Nothing imported' : parts.join(', ');
  }
}

/// Riverpod provider for [BackupService].
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.read(cacheServiceProvider),
    ref.read(crispyBackendProvider),
  );
});
