import 'package:crispy_tivi/features/shell/data/asset_shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contract support maps approved shell structure', () {
    const String source = '''
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
''';

    final ShellContractSupport contract =
        ShellContractSupport.fromContract(
          ShellContract.fromJsonString(source),
        );

    expect(contract.startupRoute, ShellRoute.home);
    expect(contract.topLevelRoutes, mainNavigationRoutes);
    expect(contract.settingsPanels.first, SettingsPanel.general);
    expect(contract.settingsPanels[2], SettingsPanel.sources);
    expect(contract.liveTvPanels, LiveTvPanel.values);
    expect(contract.mediaScopes, MediaScope.values);
    expect(contract.homeQuickAccess, <String>[
      'Search',
      'Settings',
      'Series',
      'Live TV Guide',
    ]);
    expect(contract.sourceWizardSteps, SourceWizardStep.values);
  });

  test('repository loads shell contract asset', () async {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;

    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
      if (key == AssetShellContractRepository.assetPath) {
        return const StringCodec().encodeMessage('''
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
''');
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    const AssetShellContractRepository repository =
        AssetShellContractRepository();
    final ShellContractSupport contract = await repository.load();

    expect(contract.topLevelRoutes, mainNavigationRoutes);
    expect(contract.homeQuickAccess.contains('Sources'), isFalse);
    expect(contract.sourceWizardSteps.last, SourceWizardStep.finish);
  });
}
