/// Utility class for formatting [Duration] values into human-readable strings.
class DurationFormatter {
  DurationFormatter._();

  /// Clock-style: "1:23:45" or "23:45".
  ///
  /// Used for playback position display and resume dialogs.
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ms = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$ms:$ss' : '$m:$ss';
  }

  /// Human-readable short: "2h 15m" or "45m".
  ///
  /// Used for metadata labels and search result cards.
  static String humanShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Human-readable short from milliseconds: "2h 15m" or "45m".
  ///
  /// Returns null when [durationMs] is null.
  static String? humanShortMs(int? durationMs) {
    if (durationMs == null) return null;
    return humanShort(Duration(milliseconds: durationMs));
  }

  /// Sleep-timer style: "1h 02m 30s" or "2m 30s".
  ///
  /// Includes seconds, used for sleep-timer countdown displays.
  static String sleepTimer(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ms = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${ms}m ${ss}s';
    return '${m}m ${ss}s';
  }
}
