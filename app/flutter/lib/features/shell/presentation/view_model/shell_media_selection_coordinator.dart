import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

final class ShellMediaSelectionCoordinator {
  ShellMediaSelectionCoordinator({
    required MediaPanel mediaPanel,
    required MediaScope mediaScope,
  }) : _mediaPanel = mediaPanel,
       _mediaScope = mediaScope;

  MediaPanel _mediaPanel;
  MediaScope _mediaScope;
  int _seriesSeasonIndex = 0;
  int _seriesEpisodeIndex = 0;
  int? _seriesLaunchedEpisodeIndex;

  MediaPanel get mediaPanel => _mediaPanel;
  MediaScope get mediaScope => _mediaScope;
  int get seriesSeasonIndex => _seriesSeasonIndex;
  int get seriesEpisodeIndex => _seriesEpisodeIndex;
  int? get seriesLaunchedEpisodeIndex => _seriesLaunchedEpisodeIndex;

  bool selectMediaPanel(MediaPanel panel) {
    if (_mediaPanel == panel) {
      return false;
    }
    _mediaPanel = panel;
    _seriesSeasonIndex = 0;
    _seriesEpisodeIndex = 0;
    _seriesLaunchedEpisodeIndex = null;
    return true;
  }

  bool selectMediaScope(MediaScope scope) {
    if (_mediaScope == scope) {
      return false;
    }
    _mediaScope = scope;
    return true;
  }

  bool selectSeriesSeasonIndex(int index) {
    if (_seriesSeasonIndex == index) {
      return false;
    }
    _seriesSeasonIndex = index;
    _seriesEpisodeIndex = 0;
    _seriesLaunchedEpisodeIndex = null;
    return true;
  }

  bool selectSeriesEpisodeIndex(int index) {
    if (_seriesEpisodeIndex == index) {
      return false;
    }
    _seriesEpisodeIndex = index;
    return true;
  }

  bool launchSeriesEpisode() {
    if (_seriesLaunchedEpisodeIndex == _seriesEpisodeIndex) {
      return false;
    }
    _seriesLaunchedEpisodeIndex = _seriesEpisodeIndex;
    return true;
  }
}
