import 'package:meta/meta.dart';

/// Encapsulates catch-up playback information for a programme.
///
/// Contains the resolved archive URL and metadata needed to play
/// a past programme from the channel's catch-up archive.
@immutable
class CatchupInfo {
  const CatchupInfo({
    required this.archiveUrl,
    required this.channelName,
    required this.programTitle,
    required this.startTime,
    required this.endTime,
  });

  /// The resolved archive stream URL.
  final String archiveUrl;

  /// Channel name for display.
  final String channelName;

  /// Programme title for display.
  final String programTitle;

  /// Programme start time (UTC).
  final DateTime startTime;

  /// Programme end time (UTC).
  final DateTime endTime;

  /// Convenience getter for duration.
  Duration get duration => endTime.difference(startTime);

  @override
  String toString() => 'CatchupInfo($programTitle @ $startTime)';
}
