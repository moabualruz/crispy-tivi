import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/presentation/media/media_presentation_adapter.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/media_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('movie detail emits a retained player session', (
    WidgetTester tester,
  ) async {
    final String source = await rootBundle.loadString(
      'assets/contracts/asset_media_runtime.json',
    );
    final MediaRuntimeSnapshot runtime = MediaRuntimeSnapshot.fromJsonString(
      source,
    );
    final state = MediaPresentationAdapter.build(
      runtime: runtime,
      personalization: const PersonalizationRuntimeSnapshot.empty(),
      availableScopes: MediaScope.values,
      panel: MediaPanel.movies,
      scope: MediaScope.featured,
      seriesSeasonIndex: 0,
      seriesEpisodeIndex: 0,
      launchedSeriesEpisodeIndex: 0,
    );
    PlayerSession? launchedSession;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaView(
            runtime: runtime,
            state: state,
            onSelectScope: (_) {},
            onSelectSeriesSeasonIndex: (_) {},
            onSelectSeriesEpisodeIndex: (_) {},
            onLaunchSeriesEpisode: () {},
            onLaunchPlayer:
                (PlayerSession session) => launchedSession = session,
            onToggleWatchlist: (_) {},
            watchlistContentKeys: const <String>[],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('movie-detail-card')),
      300,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-detail-card')), findsOneWidget);
    expect(find.byKey(const Key('movie-player-launch')), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-player-launch')));
    await tester.pumpAndSettle();

    expect(launchedSession, isNotNull);
    expect(launchedSession!.kind, PlayerContentKind.movie);
    expect(launchedSession!.originLabel, 'Media · Movies');
    expect(launchedSession!.activeItem.title, 'The Last Harbor');
    expect(launchedSession!.queueLabel, 'Up next');
  });
}
