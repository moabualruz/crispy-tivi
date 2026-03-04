import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';

/// Search delegate for EPG channels and programs.
class EpgSearchDelegate extends SearchDelegate<void> {
  EpgSearchDelegate({
    required this.channels,
    required this.entries,
    required this.timezone,
    required this.onChannelSelected,
    required this.onScrollToChannel,
    this.onScrollToProgram,
    this.onQueryChanged,
  });

  final List<Channel> channels;
  final Map<String, List<EpgEntry>> entries;
  final String timezone;
  final void Function(Channel) onChannelSelected;
  final void Function(String channelId) onScrollToChannel;

  /// Called when a program result is tapped — receives the channel ID and
  /// the program start time so the caller can scroll both the vertical channel
  /// row and the horizontal time axis to that program's slot.
  final void Function(String channelId, DateTime programStart)?
  onScrollToProgram;

  /// Called on every query change so callers can sync [epgProgramSearchProvider].
  final void Function(String query)? onQueryChanged;

  @override
  String get searchFieldLabel => 'Search channels & programs';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onQueryChanged?.call(query);
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    onQueryChanged?.call(query);
    return _buildSearchResults(context);
  }

  @override
  void close(BuildContext context, void result) {
    onQueryChanged?.call('');
    super.close(context, result);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Text(
          'Search for channels or programs',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    final results = searchEpgEntries(channels, entries, query);
    final matchingChannels = results.matchingChannels;
    final limitedPrograms = results.matchingPrograms;
    final totalProgramMatches = results.totalProgramMatches;

    if (matchingChannels.isEmpty && limitedPrograms.isEmpty) {
      return Center(
        child: Text(
          'No results for "$query"',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView(
      children: [
        // Channel results
        if (matchingChannels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            child: Text(
              'Channels'
              ' (${matchingChannels.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...matchingChannels.map(
            (channel) => ListTile(
              leading:
                  channel.logoUrl != null
                      ? Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(channel.logoUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      : Container(
                        width: 40,
                        height: 40,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        alignment: Alignment.center,
                        child: Text(channel.name[0].toUpperCase()),
                      ),
              title: Text(channel.name),
              subtitle: channel.group != null ? Text(channel.group!) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Show in guide',
                    onPressed: () {
                      close(context, null);
                      onScrollToChannel(channel.id);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Play',
                    onPressed: () {
                      close(context, null);
                      onChannelSelected(channel);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        // Program results
        if (limitedPrograms.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            child: Text(
              'Programs'
              ' (${limitedPrograms.length}'
              '${totalProgramMatches > 50 ? '+' : ''})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ...limitedPrograms.map(
            (match) => ListTile(
              leading:
                  match.program.isLive
                      ? Container(
                        width: 40,
                        height: 40,
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.center,
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                      : Container(
                        width: 40,
                        height: 40,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        alignment: Alignment.center,
                        child: Text(
                          _formatTime(match.program.startTime),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
              title: Text(match.program.title),
              subtitle: Text(
                '${match.channel.name}'
                ' • ${_formatDateTime(match.program.startTime)}',
              ),
              onTap: () {
                close(context, null);
                if (onScrollToProgram != null) {
                  onScrollToProgram!(match.channel.id, match.program.startTime);
                } else {
                  onScrollToChannel(match.channel.id);
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return TimezoneUtils.formatTime(dt, timezone);
  }

  String _formatDateTime(DateTime dt) {
    final adjusted = TimezoneUtils.applyTimezone(dt, timezone);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[adjusted.month - 1]}'
        ' ${adjusted.day},'
        ' ${_formatTime(dt)}';
  }
}

/// Result type for an EPG program search match.
class _ProgramMatch {
  const _ProgramMatch({required this.channel, required this.program});

  final Channel channel;
  final EpgEntry program;
}

/// Pure function: filters [channels] and [entries] by [query].
///
/// Returns a record with:
/// - `matchingChannels`: channels whose name or group contains [query]
/// - `matchingPrograms`: up to 50 programs whose title contains [query],
///   each paired with its [Channel]
/// - `totalProgramMatches`: total untruncated program hit count
///
/// Extracted from [EpgSearchDelegate._buildSearchResults] so it can be
/// unit-tested without a widget tree.
({
  List<Channel> matchingChannels,
  List<_ProgramMatch> matchingPrograms,
  int totalProgramMatches,
})
searchEpgEntries(
  List<Channel> channels,
  Map<String, List<EpgEntry>> entries,
  String query, {
  int programLimit = 50,
}) {
  final lowerQuery = query.toLowerCase();

  // Search channels by name or group.
  final matchingChannels =
      channels
          .where(
            (c) =>
                c.name.toLowerCase().contains(lowerQuery) ||
                (c.group?.toLowerCase().contains(lowerQuery) ?? false),
          )
          .toList();

  // Build channel lookup map for O(1) access.
  final channelById = <String, Channel>{};
  for (final c in channels) {
    channelById[c.id] = c;
    if (c.tvgId != null) channelById[c.tvgId!] = c;
  }

  // Search programs by title.
  final allProgramMatches = <_ProgramMatch>[];
  for (final entry in entries.entries) {
    final channelId = entry.key;
    final channel =
        channelById[channelId] ??
        Channel(id: channelId, name: 'Unknown', streamUrl: '');
    for (final program in entry.value) {
      if (program.title.toLowerCase().contains(lowerQuery)) {
        allProgramMatches.add(
          _ProgramMatch(channel: channel, program: program),
        );
      }
    }
  }

  return (
    matchingChannels: matchingChannels,
    matchingPrograms: allProgramMatches.take(programLimit).toList(),
    totalProgramMatches: allProgramMatches.length,
  );
}
