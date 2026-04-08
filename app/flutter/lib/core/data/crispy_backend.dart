/// Abstract backend interface for all platforms.
///
/// Native platforms: implemented by [FfiBackend] via
/// flutter_rust_bridge FFI.
/// Web platform: implemented by [WsBackend] via
/// WebSocket to the Rust server.
///
/// Complex types that cross the FFI boundary as JSON use
/// [Map<String, dynamic>] for single objects and
/// [List<Map<String, dynamic>>] for arrays. Simple
/// operations use native Dart types.
///
/// ## Dart↔Rust entity duplication (by design)
///
/// Domain entities (e.g. `Channel`, `VodItem`) exist as Dart classes
/// AND Rust structs. This duplication is intentional: the FFI/WebSocket
/// boundary requires JSON serialization, so each side owns its own
/// representation. Dart entities are the authoritative shape for the
/// presentation layer; Rust structs are the authoritative shape for
/// storage and business logic. The two are kept in sync via the JSON
/// contract defined in `lib/core/data/crispy_backend.dart` and
/// `rust/crates/crispy-core/src/models/`. Do NOT consolidate them.
///
/// Split across part files:
/// - [_BackendDataMethods] — channels, VOD, categories,
///   profiles, source access, channel order, EPG, watch
///   history
/// - [_BackendStorageMethods] — settings, sync metadata,
///   recordings, storage backends, transfer tasks, image
///   cache, layouts, search history, reminders, backup
/// - [_BackendParserMethods] — M3U, EPG, Xtream, Stalker,
///   VTT, S3, and recommendation parsers
/// - [_BackendAlgorithmMethods] — normalization, dedup,
///   EPG matching, DVR, S3 crypto, watch history filters,
///   Xtream URL builders, PIN, recommendations, cloud
///   sync, search, sorting, categories, timezone
library;

import 'dart:typed_data';

part 'crispy_backend_data.dart';
part 'crispy_backend_storage.dart';
part 'crispy_backend_parsers.dart';
part 'crispy_backend_algorithms.dart';

abstract class CrispyBackend
    implements
        _BackendDataMethods,
        _BackendStorageMethods,
        _BackendParserMethods,
        _BackendAlgorithmMethods {
  // ── Lifecycle ────────────────────────────────────────

  /// Initialize the backend with a database path.
  /// Must be called once before any other method.
  Future<void> init(String dbPath);

  /// Returns the crispy-core version string.
  String version();

  /// Detect the primary GPU for upscaling decisions.
  /// Returns JSON string of GpuInfo.
  Future<String> detectGpu();

  // ── Events ──────────────────────────────────────────

  /// Stream of JSON-encoded `DataChangeEvent` objects
  /// pushed by Rust after every data mutation.
  ///
  /// Native: fed by FRB `StreamSink`.
  /// Web: fed by WebSocket server-push messages.
  /// Tests: fed by [MemoryBackend.emitTestEvent].
  Stream<String> get dataEvents;

  // ── Display / AFR ─────────────────────────────────────

  /// Switch the display to the best matching refresh rate for [fps].
  ///
  /// Returns `true` when the switch succeeded, `false` otherwise.
  /// No-op on platforms that don't support display mode switching.
  Future<bool> afrSwitchMode(double fps);

  /// Restore the original display mode after AFR was engaged.
  ///
  /// Returns `true` on success.
  Future<bool> afrRestoreMode();

  // ── Cleanup ─────────────────────────────────────────

  /// Release resources (timers, sockets, streams).
  ///
  /// Called once before app exit. Default no-op — FfiBackend
  /// and MemoryBackend inherit this (Rust/GC manage their
  /// own lifecycle). WsBackend overrides with actual cleanup.
  Future<void> dispose() async {}

  // ── Maintenance ──────────────────────────────────────

  /// Delete all data from all tables.
  Future<void> clearAll();
}
