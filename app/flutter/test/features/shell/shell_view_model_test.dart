import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ShellContractSupport contract =
      ShellContractSupport.fromContract(
        ShellContract.fromJsonString('''
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
    final ShellViewModel viewModel = ShellViewModel(contract: contract);

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
    final ShellViewModel viewModel = ShellViewModel(contract: contract);

    viewModel.startReconnectWizard();

    expect(viewModel.route, ShellRoute.settings);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.sourceWizardActive, isTrue);
    expect(viewModel.sourceWizardStep, SourceWizardStep.credentials);
  });

  test('settings top-level group navigation keeps sources nested', () {
    final ShellViewModel viewModel = ShellViewModel(contract: contract);

    expect(viewModel.route, ShellRoute.home);
    expect(viewModel.settingsPanel, SettingsPanel.general);
    expect(viewModel.sourceWizardActive, isFalse);

    viewModel.selectRoute(ShellRoute.settings);
    expect(viewModel.route, ShellRoute.settings);

    viewModel.selectSettingsPanel(SettingsPanel.playback);
    expect(viewModel.settingsPanel, SettingsPanel.playback);
    expect(viewModel.sourceWizardActive, isFalse);

    viewModel.selectSettingsPanel(SettingsPanel.sources);
    expect(viewModel.settingsPanel, SettingsPanel.sources);

    viewModel.startAddSourceWizard();
    expect(viewModel.sourceWizardActive, isTrue);
    expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);

    viewModel.selectSettingsPanel(SettingsPanel.appearance);
    expect(viewModel.settingsPanel, SettingsPanel.appearance);
    expect(viewModel.sourceWizardActive, isFalse);

    viewModel.selectSettingsPanel(SettingsPanel.sources);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.sourceWizardActive, isFalse);
    expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);
  });

  test('settings search opens exact leaf and clears on manual navigation', () {
    final ShellViewModel viewModel = ShellViewModel(contract: contract);

    viewModel.selectRoute(ShellRoute.settings);
    viewModel.updateSettingsSearchQuery('storage');
    expect(viewModel.settingsSearchQuery, 'storage');
    expect(viewModel.highlightedSettingsLeaf, isNull);

    viewModel.openSettingsLeaf(
      panel: SettingsPanel.system,
      leafLabel: 'Storage',
    );

    expect(viewModel.route, ShellRoute.settings);
    expect(viewModel.settingsPanel, SettingsPanel.system);
    expect(viewModel.settingsSearchQuery, 'Storage');
    expect(viewModel.highlightedSettingsLeaf, 'Storage');

    viewModel.selectSettingsPanel(SettingsPanel.general);
    expect(viewModel.settingsSearchQuery, isEmpty);
    expect(viewModel.highlightedSettingsLeaf, isNull);
  });

  test('settings source search opens exact source detail', () {
    final ShellViewModel viewModel = ShellViewModel(contract: contract);

    viewModel.openSettingsLeaf(
      panel: SettingsPanel.sources,
      leafLabel: ShellViewModel.sourcesLeafLabel(1),
      sourceIndex: 1,
    );

    expect(viewModel.route, ShellRoute.settings);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.selectedSourceIndex, 1);
    expect(viewModel.highlightedSettingsLeaf, 'source:1');
    expect(viewModel.sourceWizardActive, isFalse);
  });

  test('live tv focus updates selection and activation changes playback', () {
    final ShellViewModel viewModel = ShellViewModel(contract: contract);

    expect(viewModel.liveTvFocusedChannelIndex, 0);
    expect(viewModel.liveTvPlayingChannelIndex, 0);

    viewModel.selectLiveTvChannelIndex(1);
    expect(viewModel.liveTvFocusedChannelIndex, 1);
    expect(viewModel.liveTvPlayingChannelIndex, 0);

    viewModel.activateLiveTvFocusedChannel();
    expect(viewModel.liveTvFocusedChannelIndex, 1);
    expect(viewModel.liveTvPlayingChannelIndex, 1);

    viewModel.selectLiveTvGroup(LiveTvGroup.sports);
    expect(viewModel.liveTvFocusedChannelIndex, 0);
    expect(viewModel.liveTvPlayingChannelIndex, 0);
  });
}
