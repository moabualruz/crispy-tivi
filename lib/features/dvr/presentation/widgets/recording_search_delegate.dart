import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../data/dvr_service.dart';
import '../../domain/entities/recording.dart';
import '../../domain/entities/recording_profile.dart';
import '../../domain/utils/dvr_payload.dart';

/// Opens the [RecordingSearchDelegate] for DVR-internal search.
void showRecordingSearch(BuildContext context, WidgetRef ref) {
  showSearch<void>(
    context: context,
    delegate: RecordingSearchDelegate(ref: ref),
  );
}

/// [SearchDelegate] that filters all DVR recordings by title,
/// channel name, and date.
///
/// Matches are updated as the user types (query debounced via
/// Flutter's search bar's own rebuild cycle).
class RecordingSearchDelegate extends SearchDelegate<void> {
  RecordingSearchDelegate({required this.ref});

  /// Ref forwarded from the calling widget so the delegate can
  /// read the [dvrServiceProvider] without its own [ProviderScope].
  final WidgetRef ref;

  @override
  String get searchFieldLabel => 'Search recordings…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    // Inherit app theme — no custom override needed.
    return Theme.of(context);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final stateAsync = ref.watch(dvrServiceProvider);

    return stateAsync.when(
      loading: () => const LoadingStateWidget(),
      error: (e, _) => ErrorStateWidget(message: 'Error: $e'),
      data: (state) {
        final all = [
          ...state.scheduled,
          ...state.inProgress,
          ...state.completed,
        ];
        final q = query.trim();

        if (q.isEmpty) {
          return _EmptyQueryHint(totalCount: all.length);
        }

        return FutureBuilder<List<Recording>>(
          future: _filter(all, q),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget();
            }
            if (snapshot.hasError) {
              return ErrorStateWidget(message: 'Error: ${snapshot.error}');
            }
            final results = snapshot.data ?? [];
            if (results.isEmpty) {
              return _NoResultsView(query: q);
            }
            return _ResultList(recordings: results);
          },
        );
      },
    );
  }

  /// Case-insensitive match against title, channel name, and date.
  /// Delegates to [CrispyBackend.filterDvrRecordings].
  Future<List<Recording>> _filter(List<Recording> recordings, String q) async {
    if (q.isEmpty) return recordings;
    final backend = ref.read(crispyBackendProvider);
    final recordingsJson = jsonEncode(recordings.map(recordingToMap).toList());
    final resultJson = await backend.filterDvrRecordings(recordingsJson, q);
    final List<dynamic> maps = jsonDecode(resultJson);
    return maps
        .cast<Map<String, dynamic>>()
        .map(_mapToRecordingFromJson)
        .toList();
  }
}

/// Deserialises a recording map returned by the Rust
/// [filterDvrRecordings] algorithm into a [Recording].
///
/// Mirrors [_mapToRecording] in `cache_service_dvr.dart` but
/// is scoped to this file to avoid leaking the private helper.
Recording _mapToRecordingFromJson(Map<String, dynamic> m) {
  final profileName = m['profile'] as String?;
  final profile =
      profileName != null
          ? RecordingProfile.values.firstWhere(
            (p) => p.name == profileName,
            orElse: () => RecordingProfile.original,
          )
          : RecordingProfile.original;

  AutoDeletePolicy parseAutoDeletePolicy(String? name) {
    if (name == null) return AutoDeletePolicy.keepAll;
    return AutoDeletePolicy.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AutoDeletePolicy.keepAll,
    );
  }

  DateTime parseNaive(String s) {
    final dt = DateTime.parse(s);
    return dt.isUtc
        ? dt
        : DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
  }

  return Recording(
    id: m['id'] as String,
    channelId: m['channel_id'] as String?,
    channelName: m['channel_name'] as String,
    channelLogoUrl: m['channel_logo_url'] as String?,
    programName: m['program_name'] as String,
    streamUrl: m['stream_url'] as String?,
    startTime: parseNaive(m['start_time'] as String),
    endTime: parseNaive(m['end_time'] as String),
    status: RecordingStatus.values.byName(m['status'] as String),
    filePath: m['file_path'] as String?,
    fileSizeBytes: m['file_size_bytes'] as int?,
    isRecurring: m['is_recurring'] as bool? ?? false,
    recurDays: m['recur_days'] as int? ?? 0,
    profile: profile,
    ownerProfileId: m['owner_profile_id'] as String?,
    isShared: m['is_shared'] as bool? ?? true,
    remoteBackendId: m['remote_backend_id'] as String?,
    remotePath: m['remote_path'] as String?,
    autoDeletePolicy: parseAutoDeletePolicy(m['auto_delete_policy'] as String?),
    keepEpisodeCount: m['keep_episode_count'] as int? ?? 5,
  );
}

// ─────────────────────────────────────────────────────────
//  Result list
// ─────────────────────────────────────────────────────────

class _ResultList extends StatelessWidget {
  const _ResultList({required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView.separated(
      padding: const EdgeInsets.all(CrispySpacing.md),
      itemCount: recordings.length,
      separatorBuilder: (_, _) => const SizedBox(height: CrispySpacing.xs),
      itemBuilder: (context, index) {
        final r = recordings[index];
        return Card(
          child: ListTile(
            leading: _statusIcon(context, r.status),
            title: Text(
              r.programName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${r.channelName} · '
              '${_formatShortDate(r.startTime)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _StatusChip(status: r.status, cs: cs, tt: tt),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
            ),
          ),
        );
      },
    );
  }

  Icon _statusIcon(BuildContext context, RecordingStatus status) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      RecordingStatus.scheduled => Icon(Icons.schedule, color: cs.primary),
      RecordingStatus.recording => Icon(
        Icons.fiber_manual_record,
        color: cs.error,
      ),
      RecordingStatus.completed => Icon(Icons.check_circle, color: cs.tertiary),
      RecordingStatus.failed => Icon(Icons.error, color: cs.error),
    };
  }

  String _formatShortDate(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month  $hour:$min';
  }
}

// ─────────────────────────────────────────────────────────
//  Status chip
// ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.cs, required this.tt});

  final RecordingStatus status;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RecordingStatus.scheduled => ('Scheduled', cs.primary),
      RecordingStatus.recording => ('Recording', cs.error),
      RecordingStatus.completed => ('Done', cs.tertiary),
      RecordingStatus.failed => ('Failed', cs.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(label, style: tt.labelSmall?.copyWith(color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Empty / no-results views
// ─────────────────────────────────────────────────────────

class _EmptyQueryHint extends StatelessWidget {
  const _EmptyQueryHint({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Search $totalCount recordings',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            'by title, channel, or date',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'No recordings match',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.xs),
          Text(
            '"$query"',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
