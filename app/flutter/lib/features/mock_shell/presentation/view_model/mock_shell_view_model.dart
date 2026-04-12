import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_contract.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:flutter/foundation.dart';

class MockShellViewModel extends ChangeNotifier {
  MockShellViewModel({required MockShellContractSupport contract})
    : _contract = contract,
      _route = contract.startupRoute,
      _liveTvPanel = contract.liveTvPanels.first,
      _liveTvGroup = contract.liveTvGroups.first,
      _mediaPanel = contract.mediaPanels.first,
      _mediaScope = contract.mediaScopes.first,
      _settingsPanel = contract.settingsPanels.first,
      _sourceWizardStep = contract.sourceWizardSteps.first;

  final MockShellContractSupport _contract;
  ShellRoute _route;
  LiveTvPanel _liveTvPanel;
  LiveTvGroup _liveTvGroup;
  MediaPanel _mediaPanel;
  MediaScope _mediaScope;
  SettingsPanel _settingsPanel;
  int _selectedSourceIndex = 0;
  bool _sourceWizardActive = false;
  SourceWizardStep _sourceWizardStep;

  ShellRoute get route => _route;
  MockShellContractSupport get contract => _contract;
  LiveTvPanel get liveTvPanel => _liveTvPanel;
  LiveTvGroup get liveTvGroup => _liveTvGroup;
  MediaPanel get mediaPanel => _mediaPanel;
  MediaScope get mediaScope => _mediaScope;
  SettingsPanel get settingsPanel => _settingsPanel;
  int get selectedSourceIndex => _selectedSourceIndex;
  bool get sourceWizardActive => _sourceWizardActive;
  SourceWizardStep get sourceWizardStep => _sourceWizardStep;

  void selectRoute(ShellRoute route) {
    if (_route == route) {
      return;
    }
    _route = route;
    if (route != ShellRoute.settings) {
      _sourceWizardActive = false;
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
    if (panel != SettingsPanel.sources) {
      _sourceWizardActive = false;
    }
    notifyListeners();
  }

  void selectSourceIndex(int index) {
    if (_selectedSourceIndex == index && !_sourceWizardActive) {
      return;
    }
    _selectedSourceIndex = index;
    _sourceWizardActive = false;
    notifyListeners();
  }

  void startAddSourceWizard() {
    _route = ShellRoute.settings;
    _settingsPanel = SettingsPanel.sources;
    _sourceWizardActive = true;
    _sourceWizardStep = _contract.sourceWizardSteps.first;
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
}
