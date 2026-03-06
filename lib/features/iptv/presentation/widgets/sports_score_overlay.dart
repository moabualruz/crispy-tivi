import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/theme/crispy_typography.dart';

part 'sports_score_overlay.g.dart';

// ── Domain model ──────────────────────────────────────────────────

/// Live score data for a sports event broadcast on a channel.
///
/// Populated via ESPN's public scoreboard API.
///
/// Matching strategy: use the channel's EPG `tvg-id` or programme
/// title to look up the live event in the sports API.
class SportScore {
  const SportScore({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.clock,
    required this.period,
  });

  /// Abbreviated home team name (e.g. "LAK", "MAN").
  final String homeTeam;

  /// Abbreviated away team name (e.g. "NYR", "CHE").
  final String awayTeam;

  /// Home team's current score.
  final int homeScore;

  /// Away team's current score.
  final int awayScore;

  /// Game clock string (e.g. "45:32", "Q3 8:14", "2nd").
  final String clock;

  /// Current period / half / quarter (e.g. "1H", "Q2", "3rd").
  final String period;

  @override
  String toString() =>
      'SportScore($homeTeam $homeScore–$awayScore $awayTeam [$clock $period])';
}

// ── State ─────────────────────────────────────────────────────────

/// State for the sports score overlay.
class SportsScoreState {
  const SportsScoreState({this.score, this.isLoading = false});

  /// The current live score, or null when no data is available.
  final SportScore? score;

  /// Whether a data fetch is in progress.
  final bool isLoading;

  SportsScoreState copyWith({SportScore? score, bool? isLoading}) {
    return SportsScoreState(
      score: score ?? this.score,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────

/// Manages live sports score data for a multiview slot.
///
/// FE-MV-09: Implemented using ESPN's public scoreboard API.
/// Note: Since we don't have the explicit event ID, this demo implementation
/// fetches the first active game as an example to demonstrate the UI overlay.
/// In production, the `channelId` should map to a specific `gameId`.
@riverpod
class SportsScore extends _$SportsScore {
  Timer? _timer;

  @override
  FutureOr<SportsScoreState> build(String channelId) async {
    // Initial fetch
    _fetchData();

    // Poll every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchData();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return const SportsScoreState(isLoading: true);
  }

  Future<void> _fetchData() async {
    try {
      // Example using ESPN's NFL scoreboard endpoint.
      // A production implementation would dynamically select the sport/league
      // based on the channel's current EPG programme.
      final url = Uri.parse(
        'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data['events'] as List<dynamic>? ?? [];

        if (events.isNotEmpty) {
          // Just grab the first game for demonstration
          final event = events[0];
          final competitions = event['competitions'] as List<dynamic>? ?? [];
          if (competitions.isNotEmpty) {
            final comp = competitions[0];
            final competitors = comp['competitors'] as List<dynamic>? ?? [];
            final status = comp['status'];

            if (competitors.length >= 2 && status != null) {
              final home = competitors.firstWhere(
                (c) => c['homeAway'] == 'home',
                orElse: () => competitors[0],
              );
              final away = competitors.firstWhere(
                (c) => c['homeAway'] == 'away',
                orElse: () => competitors[1],
              );

              final score = SportScore(
                homeTeam: home['team']['abbreviation']?.toString() ?? 'HOME',
                awayTeam: away['team']['abbreviation']?.toString() ?? 'AWAY',
                homeScore: int.tryParse(home['score']?.toString() ?? '0') ?? 0,
                awayScore: int.tryParse(away['score']?.toString() ?? '0') ?? 0,
                clock: status['displayClock']?.toString() ?? '0:00',
                period: status['period']?.toString() ?? '1',
              );

              state = AsyncData(
                SportsScoreState(score: score, isLoading: false),
              );
              return;
            }
          }
        }
      }

      // If we made it here, no valid live game was found. Keep current state but remove loading.
      if (state.hasValue) {
        state = AsyncData(state.requireValue.copyWith(isLoading: false));
      } else {
        state = const AsyncData(SportsScoreState(isLoading: false));
      }
    } catch (e) {
      debugPrint('SportsScoreOverlay: API fetch failed: $e');
      if (state.hasValue) {
        state = AsyncData(state.requireValue.copyWith(isLoading: false));
      } else {
        state = const AsyncData(SportsScoreState(isLoading: false));
      }
    }
  }

  /// Update the displayed score manually (override).
  void updateScore(SportScore score) {
    state = AsyncData(SportsScoreState(score: score, isLoading: false));
  }
}

// ── Widget ────────────────────────────────────────────────────────

/// Compact score-bug overlay shown at the bottom of a multiview slot
/// when the channel has sports content.
///
/// The overlay is only shown when:
/// 1. The channel has the `isSport: true` metadata tag.
/// 2. [SportsScoreState.score] is non-null.
///
/// Place this at the bottom of the slot's [Stack]:
///
/// ```dart
/// Stack(
///   children: [
///     VideoSlot(…),
///     Positioned(
///       bottom: CrispySpacing.xs,
///       left: CrispySpacing.xs,
///       right: CrispySpacing.xs,
///       child: SportsScoreOverlay(
///         channelId: slot.channelId,
///         isSport: channel.isSport,
///       ),
///     ),
///   ],
/// )
/// ```
class SportsScoreOverlay extends ConsumerWidget {
  const SportsScoreOverlay({
    super.key,
    required this.channelId,
    required this.isSport,
  });

  /// The channel ID used to key the [sportsScoreProvider].
  final String channelId;

  /// Whether the channel has been flagged as a primarily sports channel.
  final bool isSport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show overlay for sports channels.
    if (!isSport) return const SizedBox.shrink();

    final asyncState = ref.watch(sportsScoreProvider(channelId));

    if (asyncState.isLoading || asyncState.value == null) {
      return const Align(
        alignment: Alignment.bottomLeft,
        child: _ScoreLoadingPill(),
      );
    }

    final score = asyncState.value!.score;
    if (score == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: _ScorePill(score: score),
    );
  }
}

// ── Pill widgets ──────────────────────────────────────────────────

/// Compact pill displaying the live score bug.
///
/// Layout:
///   [HOME ABBR] [HOME SCORE] – [AWAY SCORE] [AWAY ABBR] | [PERIOD] [CLOCK]
///
/// Example: `LAK 2 – 3 NYR | 3rd 14:22`
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final SportScore score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: CrispyColors.scrimHeavy,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Home team abbreviation.
          Text(
            score.homeTeam,
            style: tt.labelSmall?.copyWith(
              color: CrispyColors.textHigh,
              fontWeight: FontWeight.bold,
              fontSize: CrispyTypography.micro,
            ),
          ),
          const SizedBox(width: CrispySpacing.xxs),
          // Score.
          Text(
            '${score.homeScore} – ${score.awayScore}',
            style: tt.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: CrispySpacing.xxs),
          // Away team abbreviation.
          Text(
            score.awayTeam,
            style: tt.labelSmall?.copyWith(
              color: CrispyColors.textHigh,
              fontWeight: FontWeight.bold,
              fontSize: CrispyTypography.micro,
            ),
          ),
          // Divider.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xs),
            child: Text(
              '|',
              style: tt.labelSmall?.copyWith(
                color: Colors.white38,
                fontSize: CrispyTypography.micro,
              ),
            ),
          ),
          // Period + clock.
          Text(
            score.period,
            style: tt.labelSmall?.copyWith(
              color: Colors.white70,
              fontSize: CrispyTypography.micro,
            ),
          ),
          const SizedBox(width: CrispySpacing.xxs),
          Text(
            score.clock,
            style: tt.labelSmall?.copyWith(
              color: Colors.white54,
              fontSize: CrispyTypography.micro,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin loading indicator shown while score data is being fetched.
class _ScoreLoadingPill extends StatelessWidget {
  const _ScoreLoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: CrispyColors.scrimMid,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            'Loading score…',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white54,
              fontSize: CrispyTypography.micro,
            ),
          ),
        ],
      ),
    );
  }
}
