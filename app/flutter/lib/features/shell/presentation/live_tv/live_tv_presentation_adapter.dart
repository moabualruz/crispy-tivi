import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/live_tv/live_tv_presentation_state.dart';

final class LiveTvPresentationAdapter {
  const LiveTvPresentationAdapter();

  static LiveTvPresentationState build({
    required LiveTvRuntimeSnapshot runtime,
    required LiveTvPanel panel,
    required String groupId,
    required int focusedChannelIndex,
    required int playingChannelIndex,
  }) {
    return LiveTvPresentationState.fromRuntime(
      runtime: runtime,
      panel: panel,
      groupId: groupId,
      focusedChannelIndex: focusedChannelIndex,
      playingChannelIndex: playingChannelIndex,
    );
  }
}
