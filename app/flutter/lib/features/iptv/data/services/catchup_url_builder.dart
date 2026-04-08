import 'dart:convert';

import '../../../../core/data/cache_service.dart';
import '../../../../core/data/crispy_backend.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entry.dart';
import '../../domain/value_objects/catchup_info.dart';

/// Builds catch-up stream URLs by delegating to the
/// Rust backend.
///
/// Supports Xtream Codes, Stalker Portal, and M3U
/// catchup-source templates. The Rust backend handles
/// all URL construction logic.
class CatchupUrlBuilder {
  const CatchupUrlBuilder(this._backend);

  final CrispyBackend _backend;

  /// Builds catch-up info for any channel type.
  ///
  /// Delegates to Rust which handles all catchup URL
  /// formats (Xtream, Stalker, Flussonic, shift,
  /// template tokens).
  ///
  /// Returns null if the channel doesn't support
  /// catch-up or the programme is not eligible.
  Future<CatchupInfo?> buildCatchup({
    required Channel channel,
    required EpgEntry entry,
  }) async {
    if (!channel.hasCatchup || !entry.isPast) {
      return null;
    }

    final channelJson = jsonEncode(channelToMap(channel));
    final startUtc = entry.startTime.millisecondsSinceEpoch ~/ 1000;
    final endUtc = entry.endTime.millisecondsSinceEpoch ~/ 1000;

    final archiveUrl = await _backend.buildCatchupUrl(
      channelJson: channelJson,
      startUtc: startUtc,
      endUtc: endUtc,
    );

    if (archiveUrl == null) return null;

    return CatchupInfo(
      archiveUrl: archiveUrl,
      channelName: channel.name,
      programTitle: entry.title,
      startTime: entry.startTime,
      endTime: entry.endTime,
    );
  }

  /// Builds catch-up info for Xtream channels.
  ///
  /// Convenience wrapper that delegates to
  /// [buildCatchup]. The [baseUrl], [username], and
  /// [password] parameters are ignored — Rust reads
  /// them from the channel's stream URL.
  Future<CatchupInfo?> buildXtreamCatchup({
    required Channel channel,
    required EpgEntry entry,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    return buildCatchup(channel: channel, entry: entry);
  }

  /// Builds catch-up info for Stalker Portal
  /// channels.
  ///
  /// Convenience wrapper that delegates to
  /// [buildCatchup]. The [baseUrl] parameter is
  /// ignored — Rust reads it from the channel data.
  Future<CatchupInfo?> buildStalkerCatchup({
    required Channel channel,
    required EpgEntry entry,
    required String baseUrl,
  }) async {
    return buildCatchup(channel: channel, entry: entry);
  }

  /// Builds catch-up info for M3U channels with
  /// catchup-source template.
  ///
  /// Convenience wrapper that delegates to
  /// [buildCatchup].
  Future<CatchupInfo?> buildM3uCatchup({
    required Channel channel,
    required EpgEntry entry,
  }) async {
    return buildCatchup(channel: channel, entry: entry);
  }
}
