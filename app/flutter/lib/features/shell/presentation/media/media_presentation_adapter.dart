import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/media/media_presentation_state.dart';

final class MediaPresentationAdapter {
  const MediaPresentationAdapter();

  static MediaPresentationState build({
    required MediaRuntimeSnapshot runtime,
    required PersonalizationRuntimeSnapshot personalization,
    required List<MediaScope> availableScopes,
    required MediaPanel panel,
    required MediaScope scope,
    required int seriesSeasonIndex,
    required int seriesEpisodeIndex,
    required int? launchedSeriesEpisodeIndex,
  }) {
    return MediaPresentationState.fromRuntime(
      runtime: runtime,
      personalization: personalization,
      availableScopes: availableScopes,
      panel: panel,
      scope: scope,
      seriesSeasonIndex: seriesSeasonIndex,
      seriesEpisodeIndex: seriesEpisodeIndex,
      launchedSeriesEpisodeIndex: launchedSeriesEpisodeIndex,
    );
  }
}
