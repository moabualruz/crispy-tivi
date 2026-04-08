import '../../../iptv/domain/entities/channel.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../domain/entities/playback_session_params.dart';
import 'playback_session_provider.dart';
import 'playback_session_state.dart';

/// Preview action extensions for [PlaybackSessionNotifier].
///
/// Split from [playback_session_provider.dart] to keep each file
/// under the 300-line limit while preserving all public API.
extension PlaybackSessionPreview on PlaybackSessionNotifier {
  /// Updates session metadata for a preview without
  /// triggering playback or mode transition.
  ///
  /// Used by the EPG screen which manages its own
  /// [EpgPreviewService] for in-page video previews.
  void startPreview({
    required String streamUrl,
    bool isLive = false,
    String? channelName,
    String? channelLogoUrl,
    String? currentProgram,
    Map<String, String>? headers,
    List<Channel>? channelList,
    int channelIndex = 0,
    Duration? startPosition,
    String? mediaType,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
    List<VodItem>? episodeList,
    String? posterUrl,
    String? seriesPosterUrl,
    String? sourceId,
  }) {
    state = PlaybackSessionState(
      streamUrl: streamUrl,
      isLive: isLive,
      channelName: channelName,
      channelLogoUrl: channelLogoUrl,
      currentProgram: currentProgram,
      headers: headers,
      channelList: channelList,
      channelIndex: channelIndex,
      startPosition: startPosition,
      mediaType: mediaType,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeList: episodeList,
      posterUrl: posterUrl,
      seriesPosterUrl: seriesPosterUrl,
      sourceId: sourceId,
    );
  }

  /// Updates session metadata for a preview from a
  /// [PlaybackSessionParams] value object.
  ///
  /// Preferred over [startPreview] for new call sites.
  void startPreviewWithParams(PlaybackSessionParams params) => startPreview(
    streamUrl: params.streamUrl,
    isLive: params.isLive,
    channelName: params.channelName,
    channelLogoUrl: params.channelLogoUrl,
    currentProgram: params.currentProgram,
    headers: params.headers,
    channelList: params.channelList,
    channelIndex: params.channelIndex,
    startPosition: params.startPosition,
    mediaType: params.mediaType,
    seriesId: params.seriesId,
    seasonNumber: params.seasonNumber,
    episodeNumber: params.episodeNumber,
    episodeList: params.episodeList,
    posterUrl: params.posterUrl,
    seriesPosterUrl: params.seriesPosterUrl,
    sourceId: params.sourceId,
  );
}
