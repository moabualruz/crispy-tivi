import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_contract.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/view_model/mock_shell_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final MockShellContractSupport contract =
      MockShellContractSupport.fromContract(
        MockShellContract.fromJsonString('''
{
  "startup_route": "Home",
  "top_level_routes": ["Home", "Live TV", "Media", "Search", "Settings"],
  "settings_groups": ["General", "Playback", "Sources", "Appearance", "System"],
  "live_tv_panels": ["Channels", "Guide"],
  "live_tv_groups": ["All", "Favorites", "News", "Sports", "Movies", "Kids"],
  "media_panels": ["Movies", "Series"],
  "media_scopes": ["Featured", "Trending", "Recent", "Library"],
  "home_quick_access": ["Search", "Settings", "Series", "Live TV Guide"],
  "source_wizard_steps": ["Source Type", "Connection", "Credentials", "Import", "Finish"]
}
'''),
      );

  test('source wizard back safety returns to previous step then overview', () {
    final MockShellViewModel viewModel = MockShellViewModel(contract: contract);

    viewModel.startAddSourceWizard();
    expect(viewModel.sourceWizardActive, isTrue);
    expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);

    viewModel.selectSourceWizardStep(SourceWizardStep.connection);
    expect(viewModel.sourceWizardStep, SourceWizardStep.connection);

    viewModel.retreatSourceWizard();
    expect(viewModel.sourceWizardActive, isTrue);
    expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);

    viewModel.retreatSourceWizard();
    expect(viewModel.sourceWizardActive, isFalse);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
  });

  test('reconnect flow starts at credentials step', () {
    final MockShellViewModel viewModel = MockShellViewModel(contract: contract);

    viewModel.startReconnectWizard();

    expect(viewModel.route, ShellRoute.settings);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.sourceWizardActive, isTrue);
    expect(viewModel.sourceWizardStep, SourceWizardStep.credentials);
  });
}
