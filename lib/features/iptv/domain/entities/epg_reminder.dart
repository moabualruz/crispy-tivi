// FE-EPG-02 — domain entity (clock-injectable)

import 'package:meta/meta.dart';

/// A user-set reminder for an upcoming EPG programme.
@immutable
class EpgReminder {
  const EpgReminder({
    required this.channelId,
    required this.programId,
    required this.startTime,
    required this.title,
    required this.channelName,
  });

  /// Channel the reminder is set on.
  final String channelId;

  /// Unique identifier: "${channelId}_${startTime.millisecondsSinceEpoch}".
  final String programId;

  /// Programme start time (UTC).
  final DateTime startTime;

  /// Programme title for display.
  final String title;

  /// Human-readable channel name.
  final String channelName;

  /// Whether this reminder should fire soon (≤ 5 min before start).
  ///
  /// [now] is the caller-supplied clock value (UTC). Pass
  /// `DateTime.now().toUtc()` in production code and a fixed
  /// `DateTime` in tests.
  bool isDue(DateTime now) {
    final remaining = startTime.difference(now);
    return remaining.inMinutes <= 5 && remaining.inSeconds > 0;
  }

  /// Whether this programme has already started.
  ///
  /// [now] is the caller-supplied clock value (UTC).
  bool isPast(DateTime now) => now.isAfter(startTime);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpgReminder &&
          channelId == other.channelId &&
          programId == other.programId;

  @override
  int get hashCode => Object.hash(channelId, programId);

  @override
  String toString() => 'EpgReminder($title @ $startTime)';
}
