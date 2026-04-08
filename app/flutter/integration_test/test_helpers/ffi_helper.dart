import 'dart:convert';
import 'dart:io';

import 'package:crispy_tivi/core/data/app_directories.dart';
import 'package:crispy_tivi/main.dart' as app_main;
import 'package:crispy_tivi/src/rust/api/lifecycle.dart' as rust_lifecycle;
import 'package:crispy_tivi/src/rust/api/settings.dart' as rust_settings;
import 'package:crispy_tivi/src/rust/frb_generated.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Idempotent helper to initialize Rust backend state via FFI.
/// Ensures that `RustLib.init()` is safely called only once
/// across modular test suites.
///
/// Each test run gets an isolated temp database directory so
/// integration tests never share the production database and
/// parallel targets on the same machine don't collide.
abstract class FfiTestHelper {
  static bool _hasInitialized = false;
  static bool _backendInitialized = false;
  static bool _platformMocksInstalled = false;
  static Directory? _testDir;
  static const _kCredsJsonOverride =
      String.fromEnvironment('CRISPY_TEST_CREDS_JSON');

  /// Create an isolated temp directory and point
  /// [AppDirectories] at it. Call BEFORE `app.main()`.
  ///
  /// Pass an optional [tag] (e.g. `'windows'`, `'phone'`) to
  /// disambiguate when multiple targets run on the same host.
  static Future<void> ensureTestIsolation({String? tag}) async {
    _installPlatformChannelMocks();
    if (_testDir != null) return; // already isolated
    // Skip single-instance socket check so app.main() can be
    // called multiple times in the same test process.
    app_main.skipSingleInstanceCheck = true;
    final suffix = tag != null ? '_$tag' : '';
    _testDir = await Directory.systemTemp.createTemp('crispy_test$suffix');
    AppDirectories.testRoot = _testDir!.path;
    // Pre-create sub-dirs so the app doesn't need to.
    await Directory('${_testDir!.path}/data').create(recursive: true);
    await Directory('${_testDir!.path}/cache').create(recursive: true);
  }

  static void _installPlatformChannelMocks() {
    if (_platformMocksInstalled) return;
    final binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (methodCall) async => null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.crispytivi/pip_player_android'),
      (methodCall) async => null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.crispytivi/pip_player_android/events'),
      (methodCall) async => null,
    );
    _platformMocksInstalled = true;
  }

  /// Ensure the Rust backend is initialized.
  static Future<void> ensureRustInitialized() async {
    if (!_hasInitialized) {
      await RustLib.init();
      _hasInitialized = true;
    }
  }

  /// Initialize the Rust backend with the test database.
  /// Must be called AFTER [ensureTestIsolation] and
  /// [ensureRustInitialized].
  static Future<void> ensureBackendInitialized() async {
    if (_backendInitialized) return;
    await ensureRustInitialized();
    final dbPath = '${AppDirectories.data}/crispy_tivi_v2.sqlite';
    try {
      await rust_lifecycle.initBackend(dbPath: dbPath);
    } catch (_) {
      // Already initialized (OnceLock) — ignore.
    }
    _backendInitialized = true;
  }

  /// Pre-seed an IPTV source so the onboarding wizard is
  /// bypassed during integration tests.
  ///
  /// Reads credentials from JSON files:
  /// 1. `test_creds.local.json` (untracked — real creds)
  /// 2. `test_creds.json` (tracked — mock fallback)
  static Future<void> seedTestSource() async {
    await ensureBackendInitialized();
    final creds = _loadTestCredentials();
    final sourcesJson = '[${jsonEncode(creds)}]';
    await rust_settings.setSetting(
      key: 'crispy_tivi_playlist_sources',
      value: sourcesJson,
    );
  }

  /// Loads test credentials.
  /// On desktop: reads from JSON files (local.json > fallback.json).
  /// On mobile (Android/iOS): files don't exist on-device, falls back
  /// to either the compile-time override or the embedded
  /// [_kFallbackCreds] constant.
  static Map<String, dynamic> _loadTestCredentials() {
    if (_kCredsJsonOverride.isNotEmpty) {
      return jsonDecode(_kCredsJsonOverride) as Map<String, dynamic>;
    }
    final dir = 'integration_test/test_helpers';
    try {
      final localFile = File('$dir/test_creds.local.json');
      if (localFile.existsSync()) {
        return jsonDecode(localFile.readAsStringSync()) as Map<String, dynamic>;
      }
      final fallbackFile = File('$dir/test_creds.json');
      if (fallbackFile.existsSync()) {
        return jsonDecode(fallbackFile.readAsStringSync())
            as Map<String, dynamic>;
      }
    } catch (_) {
      // File I/O not available (e.g. Android/iOS) — use embedded.
    }
    return Map<String, dynamic>.from(_kFallbackCreds);
  }

  /// Embedded fallback credentials for on-device tests where
  /// filesystem paths are not available.
  static const _kFallbackCreds = <String, dynamic>{
    'id': 'test_mock_wizju',
    'name': 'Wizju Mock',
    'url': 'https://xtream-codes-mock-api.wizju.com',
    'type': 'xtream',
    'username': 'test_user',
    'password': 'test_pass',
    'epgUrl':
        'https://xtream-codes-mock-api.wizju.com/xmltv.php?username=test_user&password=test_pass',
    'refreshIntervalMinutes': 60,
  };

  /// Delete the test database directory.
  /// Call in `tearDownAll` or after the test suite.
  /// Best-effort on Windows where SQLite may hold file locks.
  static Future<void> cleanup() async {
    if (_testDir == null) return;
    try {
      if (_testDir!.existsSync()) {
        await _testDir!.delete(recursive: true);
      }
    } catch (_) {
      // SQLite WAL file may be locked on Windows — ignore.
      // The OS temp directory cleaner will handle it.
    }
    _testDir = null;
  }

  static Future<void> setupGuestProfileBackendState() async {
    await ensureRustInitialized();
  }

  static Future<void> setupSettingsBackendState() async {
    await ensureRustInitialized();
  }

  static Future<void> setupNavigationBackendState() async {
    await ensureRustInitialized();
  }
}
