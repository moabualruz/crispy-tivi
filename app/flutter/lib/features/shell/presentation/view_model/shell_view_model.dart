import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:flutter/foundation.dart';

class ShellViewModel extends ChangeNotifier {
  ShellViewModel({required ShellContractSupport contract})
    : _contract = contract,
      _route = contract.startupRoute,
      _liveTvPanel = contract.liveTvPanels.first,
      _liveTvGroup = contract.liveTvGroups.first,
      _mediaPanel = contract.mediaPanels.first,
      _mediaScope = contract.mediaScopes.first,
      _seriesSeasonIndex = 0,
      _seriesEpisodeIndex = 0,
      _seriesLaunchedEpisodeIndex = null,
      _settingsPanel = contract.settingsPanels.first,
      _sourceWizardStep = contract.sourceWizardSteps.first;

  final ShellContractSupport _contract;
  ShellRoute _route;
  LiveTvPanel _liveTvPanel;
  LiveTvGroup _liveTvGroup;
  int _liveTvFocusedChannelIndex = 0;
  int _liveTvPlayingChannelIndex = 0;
  MediaPanel _mediaPanel;
  MediaScope _mediaScope;
  int _seriesSeasonIndex;
  int _seriesEpisodeIndex;
  int? _seriesLaunchedEpisodeIndex;
  SettingsPanel _settingsPanel;
  int _selectedSourceIndex = 0;
  bool _sourceWizardActive = false;
  SourceWizardStep _sourceWizardStep;
  String _settingsSearchQuery = '';
  String? _highlightedSettingsLeaf;

  ShellRoute get route => _route;
  ShellContractSupport get contract => _contract;
  LiveTvPanel get liveTvPanel => _liveTvPanel;
  LiveTvGroup get liveTvGroup => _liveTvGroup;
  int get liveTvFocusedChannelIndex => _liveTvFocusedChannelIndex;
  int get liveTvPlayingChannelIndex => _liveTvPlayingChannelIndex;
  MediaPanel get mediaPanel => _mediaPanel;
  MediaScope get mediaScope => _mediaScope;
  int get seriesSeasonIndex => _seriesSeasonIndex;
  int get seriesEpisodeIndex => _seriesEpisodeIndex;
  int? get seriesLaunchedEpisodeIndex => _seriesLaunchedEpisodeIndex;
  SettingsPanel get settingsPanel => _settingsPanel;
  int get selectedSourceIndex => _selectedSourceIndex;
  bool get sourceWizardActive => _sourceWizardActive;
  SourceWizardStep get sourceWizardStep => _sourceWizardStep;
  String get settingsSearchQuery => _settingsSearchQuery;
  String? get highlightedSettingsLeaf => _highlightedSettingsLeaf;

  void selectRoute(ShellRoute route) {
    if (_route == route) {
      return;
    }
    _route = route;
    if (route != ShellRoute.settings) {
      _sourceWizardActive = false;
      _settingsSearchQuery = '';
      _highlightedSettingsLeaf = null;
    }
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
    _liveTvFocusedChannelIndex = 0;
    _liveTvPlayingChannelIndex = 0;
    notifyListeners();
  }

  void selectLiveTvChannelIndex(int index) {
    if (_liveTvFocusedChannelIndex == index) {
      return;
    }
    _liveTvFocusedChannelIndex = index;
    notifyListeners();
  }

  void activateLiveTvFocusedChannel() {
    if (_liveTvPlayingChannelIndex == _liveTvFocusedChannelIndex) {
      return;
    }
    _liveTvPlayingChannelIndex = _liveTvFocusedChannelIndex;
    notifyListeners();
  }

  void selectMediaPanel(MediaPanel panel) {
    if (_mediaPanel == panel) {
      return;
    }
    _mediaPanel = panel;
    _seriesSeasonIndex = 0;
    _seriesEpisodeIndex = 0;
    _seriesLaunchedEpisodeIndex = null;
    notifyListeners();
  }

  void selectMediaScope(MediaScope scope) {
    if (_mediaScope == scope) {
      return;
    }
    _mediaScope = scope;
    notifyListeners();
  }

  void selectSeriesSeasonIndex(int index) {
    if (_seriesSeasonIndex == index) {
      return;
    }
    _seriesSeasonIndex = index;
    _seriesEpisodeIndex = 0;
    _seriesLaunchedEpisodeIndex = null;
    notifyListeners();
  }

  void selectSeriesEpisodeIndex(int index) {
    if (_seriesEpisodeIndex == index) {
      return;
    }
    _seriesEpisodeIndex = index;
    notifyListeners();
  }

  void launchSeriesEpisode() {
    if (_seriesLaunchedEpisodeIndex == _seriesEpisodeIndex) {
      return;
    }
    _seriesLaunchedEpisodeIndex = _seriesEpisodeIndex;
    notifyListeners();
  }

  void selectSettingsPanel(SettingsPanel panel) {
    if (_settingsPanel == panel) {
      return;
    }
    _settingsPanel = panel;
    if (panel != SettingsPanel.sources) {
      _sourceWizardActive = false;
    }
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = null;
    notifyListeners();
  }

  void selectSourceIndex(int index) {
    if (_selectedSourceIndex == index && !_sourceWizardActive) {
      return;
    }
    _selectedSourceIndex = index;
    _sourceWizardActive = false;
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = sourcesLeafLabel(index);
    notifyListeners();
  }

  void startAddSourceWizard() {
    _route = ShellRoute.settings;
    _settingsPanel = SettingsPanel.sources;
    _sourceWizardActive = true;
    _sourceWizardStep = _contract.sourceWizardSteps.first;
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = null;
    notifyListeners();
  }

  void startReconnectWizard() {
    _route = ShellRoute.settings;
    _settingsPanel = SettingsPanel.sources;
    _sourceWizardActive = true;
    _sourceWizardStep =
        _contract.sourceWizardSteps.contains(SourceWizardStep.credentials)
            ? SourceWizardStep.credentials
            : _contract.sourceWizardSteps.first;
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = null;
    notifyListeners();
  }

  void selectSourceWizardStep(SourceWizardStep step) {
    if (!_sourceWizardActive || _sourceWizardStep == step) {
      return;
    }
    _sourceWizardStep = step;
    notifyListeners();
  }

  void advanceSourceWizard() {
    if (!_sourceWizardActive) {
      return;
    }
    final int currentIndex = _contract.sourceWizardSteps.indexOf(
      _sourceWizardStep,
    );
    if (currentIndex < _contract.sourceWizardSteps.length - 1) {
      _sourceWizardStep = _contract.sourceWizardSteps[currentIndex + 1];
      notifyListeners();
      return;
    }
    _sourceWizardActive = false;
    notifyListeners();
  }

  void retreatSourceWizard() {
    if (!_sourceWizardActive) {
      return;
    }
    final int currentIndex = _contract.sourceWizardSteps.indexOf(
      _sourceWizardStep,
    );
    if (currentIndex > 0) {
      _sourceWizardStep = _contract.sourceWizardSteps[currentIndex - 1];
      notifyListeners();
      return;
    }
    _sourceWizardActive = false;
    notifyListeners();
  }

  void updateSettingsSearchQuery(String value) {
    if (_settingsSearchQuery == value) {
      return;
    }
    _settingsSearchQuery = value;
    _highlightedSettingsLeaf = null;
    notifyListeners();
  }

  void clearSettingsSearch() {
    if (_settingsSearchQuery.isEmpty && _highlightedSettingsLeaf == null) {
      return;
    }
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = null;
    notifyListeners();
  }

  void openSettingsLeaf({
    required SettingsPanel panel,
    required String leafLabel,
    int? sourceIndex,
  }) {
    _route = ShellRoute.settings;
    _settingsPanel = panel;
    _settingsSearchQuery = leafLabel;
    _highlightedSettingsLeaf = leafLabel;
    _sourceWizardActive = false;
    if (panel == SettingsPanel.sources && sourceIndex != null) {
      _selectedSourceIndex = sourceIndex;
    }
    notifyListeners();
  }

  static String sourcesLeafLabel(int index) => 'source:$index';
}
