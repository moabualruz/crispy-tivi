import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_typography.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';

/// Normalises [s] for accent-insensitive matching.
///
/// Lowercases the string then replaces common Latin diacritics with their
/// ASCII base characters so that, e.g., "Élysée" matches "elysee".
String _normalize(String s) {
  const diacriticMap = <String, String>{
    // grave
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
    // acute
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
    'ý': 'y',
    // circumflex
    'â': 'a', 'ê': 'e', 'î': 'i', 'ô': 'o', 'û': 'u',
    // tilde
    'ã': 'a', 'ñ': 'n', 'õ': 'o',
    // umlaut / diaeresis
    'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
    'ÿ': 'y',
    // ring, stroke, cedilla, ligatures
    'å': 'a', 'ø': 'o', 'ç': 'c',
    'ð': 'd', 'þ': 'th', 'ß': 'ss',
    // Central / Eastern European
    'ă': 'a', 'ą': 'a',
    'ć': 'c', 'č': 'c',
    'ď': 'd',
    'ę': 'e', 'ě': 'e',
    'ğ': 'g', 'ĝ': 'g',
    'ĥ': 'h',
    'ĩ': 'i', 'ĭ': 'i',
    'ĵ': 'j',
    'ĺ': 'l', 'ľ': 'l', 'ł': 'l',
    'ń': 'n', 'ň': 'n',
    'ő': 'o',
    'ŕ': 'r', 'ř': 'r',
    'ś': 's', 'ş': 's', 'š': 's',
    'ť': 't',
    'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u',
    'ŵ': 'w',
    'ź': 'z', 'ż': 'z', 'ž': 'z',
  };
  var result = s.toLowerCase();
  for (final entry in diacriticMap.entries) {
    if (result.contains(entry.key)) {
      result = result.replaceAll(entry.key, entry.value);
    }
  }
  return result;
}

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
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear search',
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
          'Search channels, programs\u2026',
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
          'No results found',
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
            (channel) => Semantics(
              label: 'Channel: ${channel.name}',
              child: ListTile(
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
            (match) => Semantics(
              label: 'Program: ${match.program.title} on ${match.channel.name}',
              child: ListTile(
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
                              fontSize: CrispyTypography.micro,
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
                            style: const TextStyle(
                              fontSize: CrispyTypography.micro,
                            ),
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
                    onScrollToProgram!(
                      match.channel.id,
                      match.program.startTime,
                    );
                  } else {
                    onScrollToChannel(match.channel.id);
                  }
                },
              ),
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
/// Matching is accent-insensitive: both query and target strings are
/// normalised via [_normalize] before comparison.
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
  final normQuery = _normalize(query);

  // Search channels by name or group.
  final matchingChannels =
      channels
          .where(
            (c) =>
                _normalize(c.name).contains(normQuery) ||
                (_normalize(c.group ?? '').contains(normQuery) &&
                    (c.group?.isNotEmpty ?? false)),
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
      if (_normalize(program.title).contains(normQuery)) {
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
