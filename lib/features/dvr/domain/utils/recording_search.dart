import '../../../../core/utils/date_format_utils.dart';
import '../entities/recording.dart';

/// Filters [recordings] by [query] using a case-insensitive match
/// against each recording's program name, channel name, and start
/// date (formatted as "YYYY-MM-DD").
///
/// Returns [recordings] unchanged when [query] is empty.
///
/// Pure function — no Flutter or framework imports.
List<Recording> filterRecordings(List<Recording> recordings, String query) {
  if (query.isEmpty) return recordings;
  final lower = query.toLowerCase();
  return recordings.where((r) {
    return r.programName.toLowerCase().contains(lower) ||
        r.channelName.toLowerCase().contains(lower) ||
        formatYMD(r.startTime).contains(lower);
  }).toList();
}
