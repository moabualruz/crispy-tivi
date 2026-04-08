import '../../../../core/data/cache_service.dart';
import '../../../../core/data/crispy_backend.dart';
import '../../domain/entities/epg_entry.dart';

/// Parses XMLTV electronic program guide data into
/// [EpgEntry] entities by delegating to the Rust
/// backend.
///
/// All heavy XML parsing is performed in Rust. Dart
/// only converts the returned maps to domain entities.
///
/// For large files, Rust handles concurrency
/// internally — no separate isolate is needed.
abstract final class EpgParser {
  /// Parses XMLTV content via [CrispyBackend].
  ///
  /// Returns a list of [EpgEntry] entities.
  static Future<List<EpgEntry>> parseContent(
    String content,
    CrispyBackend backend,
  ) async {
    if (content.trim().isEmpty) return const [];

    final maps = await backend.parseEpg(content);
    return maps.map(mapToEpgEntry).toList();
  }

  /// Parses XMLTV content in the Rust backend.
  ///
  /// Equivalent to [parseContent] — Rust handles
  /// concurrency internally.
  static Future<List<EpgEntry>> parseInIsolate(
    String content,
    CrispyBackend backend,
  ) async {
    return parseContent(content, backend);
  }

  /// Extracts XMLTV `<channel>` display names via
  /// [CrispyBackend].
  ///
  /// Returns {xmltvId: displayName}.
  static Future<Map<String, String>> extractChannelNames(
    String content,
    CrispyBackend backend,
  ) async {
    return backend.extractEpgChannelNames(content);
  }

  /// Extracts XMLTV `<channel>` display names in
  /// the Rust backend.
  ///
  /// Equivalent to [extractChannelNames] — Rust
  /// handles concurrency internally.
  static Future<Map<String, String>> extractChannelNamesInIsolate(
    String content,
    CrispyBackend backend,
  ) async {
    return extractChannelNames(content, backend);
  }
}
