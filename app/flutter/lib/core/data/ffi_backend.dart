import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../src/rust/api/all.dart' as rust_api;
import '../../src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'crispy_backend.dart';

part 'ffi_backend_buffer.dart';
part 'ffi_backend_channels.dart';
part 'ffi_backend_vod.dart';
part 'ffi_backend_epg.dart';
part 'ffi_backend_dvr.dart';
part 'ffi_backend_profiles.dart';
part 'ffi_backend_settings.dart';
part 'ffi_backend_sync.dart';
part 'ffi_backend_parsers.dart';
part 'ffi_backend_stream_health.dart';

/// Decode a JSON string into a list of string-keyed maps.
///
/// Used throughout FFI backend parts to avoid repeating
/// the inline cast pattern. Returns an empty list on
/// malformed JSON to prevent crashes from corrupt FFI data.
List<Map<String, dynamic>> _decodeJsonList(String json) {
  try {
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('FFI JSON decode error in _decodeJsonList: $e');
    return [];
  }
}

/// Base class that exposes the Rust FFI API import to
/// all mixins.
///
/// Not exported — consumers use [FfiBackend].
abstract class _FfiBackendBase {
  // Intentionally empty — mixins access `rust_api`
  // directly via the library-level import.
}

/// [CrispyBackend] implementation using
/// flutter_rust_bridge FFI bindings. Handles JSON
/// encode/decode internally so callers work with
/// native Dart types.
class FfiBackend extends _FfiBackendBase
    with
        _FfiBufferMixin,
        _FfiChannelsMixin,
        _FfiVodMixin,
        _FfiEpgMixin,
        _FfiDvrMixin,
        _FfiProfilesMixin,
        _FfiSettingsMixin,
        _FfiSyncMixin,
        _FfiParsersMixin,
        _FfiStreamHealthMixin
    implements CrispyBackend {
  Stream<String>? _eventStream;

  // ── Lifecycle ────────────────────────────────────

  @override
  Future<void> init(String dbPath) async {
    try {
      await RustLib.init();
    } on StateError {
      // RustLib.init throws if called repeatedly across integration tests.
    }

    try {
      await rust_api.initBackend(dbPath: dbPath);
    } catch (e) {
      // Intentional: tolerate repeat initializations.
      debugPrint('[FfiBackend] init skipped (likely repeat): $e');
    }
    _eventStream ??= rust_api.subscribeDataEvents();
  }

  @override
  String version() => rust_api.crispyVersion();

  @override
  Future<String> detectGpu() async {
    return await rust_api.detectGpu();
  }

  // ── Events ─────────────────────────────────────

  @override
  Stream<String> get dataEvents => _eventStream ?? const Stream.empty();

  // ── Cleanup ────────────────────────────────────

  @override
  Future<void> dispose() async {
    // Rust manages its own lifecycle via OnceLock — no-op.
  }

  // ── Display / AFR ────────────────────────────

  @override
  Future<bool> afrSwitchMode(double fps) async {
    return await rust_api.afrSwitchMode(fps: fps);
  }

  @override
  Future<bool> afrRestoreMode() async {
    return await rust_api.afrRestoreMode();
  }

  // ── App Update ────────────────────────────────

  @override
  Future<String> checkForUpdate(String currentVersion, String repoUrl) async {
    return await rust_api.checkForUpdate(
      currentVersion: currentVersion,
      repoUrl: repoUrl,
    );
  }

  @override
  String? getPlatformAssetUrl(String assetsJson, String platform) {
    return rust_api.getPlatformAssetUrl(
      assetsJson: assetsJson,
      platform: platform,
    );
  }
}
