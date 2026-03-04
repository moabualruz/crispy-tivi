import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path_provider/path_provider.dart' as pp;

/// Centralized home-folder path resolution for all
/// platforms.
///
/// On desktop, data lives under `~/.crispytivi/` so
/// multiple app instances share one database, settings,
/// and cache.
///
/// On mobile (Android/iOS), data lives under the
/// platform-provided app documents directory.
abstract final class AppDirectories {
  static const _appFolder = '.crispytivi';

  static String? _resolvedRoot;

  /// Override root for testing. Sets the root without filesystem IO.
  @visibleForTesting
  static set testRoot(String path) => _resolvedRoot = path;

  /// Root data directory.
  ///
  /// Desktop: `~/.crispytivi/`
  /// Mobile: `{appDocDir}/.crispytivi/`
  static String get root {
    assert(_resolvedRoot != null, 'Call AppDirectories.ensureCreated() first');
    return _resolvedRoot!;
  }

  /// Database files: `{root}/data/`
  static String get data => '$root/data';

  /// DVR recordings: `{root}/recordings/`
  static String get recordings => '$root/recordings';

  /// Backup exports: `{root}/backups/`
  static String get backups => '$root/backups';

  /// Cache files: `{root}/cache/`
  static String get cache => '$root/cache';

  /// Ensure all directories exist.
  ///
  /// Call once during app startup, before database init.
  /// No-op on web (uses IndexedDB).
  static Future<void> ensureCreated() async {
    if (kIsWeb) return;
    final home = await _resolveHomeDir();
    _resolvedRoot = '$home/$_appFolder';
    for (final dir in [data, recordings, backups, cache]) {
      await Directory(dir).create(recursive: true);
    }
  }

  static Future<String> _resolveHomeDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await pp.getApplicationDocumentsDirectory();
      return dir.path;
    }
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
    }
    return Platform.environment['HOME'] ?? '/tmp';
  }
}
