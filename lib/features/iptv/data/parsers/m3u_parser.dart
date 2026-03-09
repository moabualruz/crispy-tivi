import '../../../../core/data/cache_service.dart';
import '../../../../core/data/crispy_backend.dart';
import '../../domain/entities/channel.dart';

/// Result of M3U parsing, including channels and any
/// EPG URL discovered in the `#EXTM3U` header.
class M3uParseResult {
  const M3uParseResult({
    required this.channels,
    this.epgUrl,
    this.errors = const [],
  });

  /// Parsed channels.
  final List<Channel> channels;

  /// EPG URL from `url-tvg` or `x-tvg-url` header
  /// attribute in the `#EXTM3U` line.
  final String? epgUrl;

  /// Parse errors for individual entries that failed.
  /// Callers can log these without losing valid channels.
  final List<String> errors;
}

/// Parses M3U/M3U8 playlist content into [Channel]
/// entities by delegating to the Rust backend.
///
/// All heavy parsing is performed in Rust. Dart only
/// converts the returned maps to domain entities.
///
/// ```dart
/// final result = await M3uParser.parseContent(
///   m3uString,
///   backend,
/// );
/// final channels = result.channels;
/// final epgUrl = result.epgUrl; // may be null
/// ```
abstract final class M3uParser {
  /// Parses M3U content via [CrispyBackend].
  ///
  /// Delegates to Rust for parsing and converts
  /// result maps to [Channel] entities.
  static Future<M3uParseResult> parseContent(
    String content,
    CrispyBackend backend,
  ) async {
    if (content.trim().isEmpty) {
      return const M3uParseResult(channels: []);
    }

    final result = await backend.parseM3u(content);

    final rawChannels = result['channels'] as List<dynamic>? ?? [];
    final channels =
        rawChannels.cast<Map<String, dynamic>>().map(mapToChannel).toList();

    final epgUrl = result['epg_url'] as String?;
    final rawErrors = result['errors'] as List<dynamic>? ?? [];
    final errors = rawErrors.cast<String>();

    return M3uParseResult(channels: channels, epgUrl: epgUrl, errors: errors);
  }

  /// Parses M3U content in the Rust backend.
  ///
  /// Equivalent to [parseContent] — Rust handles
  /// concurrency internally, so no separate isolate
  /// is needed.
  static Future<M3uParseResult> parseInIsolate(
    String content,
    CrispyBackend backend,
  ) async {
    return parseContent(content, backend);
  }
}
