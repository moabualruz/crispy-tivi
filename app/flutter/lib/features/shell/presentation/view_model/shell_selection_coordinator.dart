import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_live_tv_selection_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_media_selection_coordinator.dart';

final class ShellSelectionCoordinator {
  ShellSelectionCoordinator({
    required ShellLiveTvSelectionCoordinator liveTvCoordinator,
    required ShellMediaSelectionCoordinator mediaCoordinator,
    required void Function() notifyChanged,
  }) : _liveTvCoordinator = liveTvCoordinator,
       _mediaCoordinator = mediaCoordinator,
       _notifyChanged = notifyChanged;

  final ShellLiveTvSelectionCoordinator _liveTvCoordinator;
  final ShellMediaSelectionCoordinator _mediaCoordinator;
  final void Function() _notifyChanged;

  void selectLiveTvPanel(LiveTvPanel panel) {
    _notifyIfChanged(_liveTvCoordinator.selectLiveTvPanel(panel));
  }

  void selectLiveTvGroup(String groupId) {
    _notifyIfChanged(_liveTvCoordinator.selectLiveTvGroup(groupId));
  }

  void selectLiveTvChannelIndex(int index) {
    _notifyIfChanged(_liveTvCoordinator.selectLiveTvChannelIndex(index));
  }

  void activateLiveTvFocusedChannel() {
    _notifyIfChanged(_liveTvCoordinator.activateLiveTvFocusedChannel());
  }

  void selectMediaPanel(MediaPanel panel) {
    _notifyIfChanged(_mediaCoordinator.selectMediaPanel(panel));
  }

  void selectMediaScope(MediaScope scope) {
    _notifyIfChanged(_mediaCoordinator.selectMediaScope(scope));
  }

  void selectSeriesSeasonIndex(int index) {
    _notifyIfChanged(_mediaCoordinator.selectSeriesSeasonIndex(index));
  }

  void selectSeriesEpisodeIndex(int index) {
    _notifyIfChanged(_mediaCoordinator.selectSeriesEpisodeIndex(index));
  }

  void launchSeriesEpisode() {
    _notifyIfChanged(_mediaCoordinator.launchSeriesEpisode());
  }

  void _notifyIfChanged(bool changed) {
    if (changed) {
      _notifyChanged();
    }
  }
}
