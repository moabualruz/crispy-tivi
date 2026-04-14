import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/presentation/shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ShellContractSupport contract = ShellContractSupport.fromContract(
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

  testWidgets('real-mode settings panels stay populated without shell content', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShellPage(
            contract: contract,
            content: const ShellContentSnapshot.empty(),
            sourceRegistryRepository: const AssetSourceRegistryRepository(),
            personalizationRepository: const NoopPersonalizationRuntimeRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-sidebar-General')));
    await tester.pumpAndSettle();

    expect(find.text('Startup route'), findsWidgets);
  });
}
