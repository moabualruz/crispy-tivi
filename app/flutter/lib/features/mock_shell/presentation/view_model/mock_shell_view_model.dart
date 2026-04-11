import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:flutter/foundation.dart';

class MockShellViewModel extends ChangeNotifier {
  ShellRoute _route = ShellRoute.home;
  LiveTvPanel _liveTvPanel = LiveTvPanel.channels;
  LiveTvGroup _liveTvGroup = LiveTvGroup.allChannels;
  MediaPanel _mediaPanel = MediaPanel.movies;
  MediaScope _mediaScope = MediaScope.featured;
  SettingsPanel _settingsPanel = SettingsPanel.general;

  ShellRoute get route => _route;
  LiveTvPanel get liveTvPanel => _liveTvPanel;
  LiveTvGroup get liveTvGroup => _liveTvGroup;
  MediaPanel get mediaPanel => _mediaPanel;
  MediaScope get mediaScope => _mediaScope;
  SettingsPanel get settingsPanel => _settingsPanel;

  void selectRoute(ShellRoute route) {
    if (_route == route) {
      return;
    }
    _route = route;
    notifyListeners();
  }

  void selectLiveTvPanel(LiveTvPanel panel) {
    if (_liveTvPanel == panel) {
      return;
    }
    _liveTvPanel = panel;
    notifyListeners();
  }

  void selectLiveTvGroup(LiveTvGroup group) {
    if (_liveTvGroup == group) {
      return;
    }
    _liveTvGroup = group;
    notifyListeners();
  }

  void selectMediaPanel(MediaPanel panel) {
    if (_mediaPanel == panel) {
      return;
    }
    _mediaPanel = panel;
    notifyListeners();
  }

  void selectMediaScope(MediaScope scope) {
    if (_mediaScope == scope) {
      return;
    }
    _mediaScope = scope;
    notifyListeners();
  }

  void selectSettingsPanel(SettingsPanel panel) {
    if (_settingsPanel == panel) {
      return;
    }
    _settingsPanel = panel;
    notifyListeners();
  }
}
