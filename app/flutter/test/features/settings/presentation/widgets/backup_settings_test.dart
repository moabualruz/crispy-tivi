import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/settings/presentation/widgets/backup_settings.dart';

AppConfig _minimalConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.1',
  api: ApiConfig(
    baseUrl: 'http://test',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 2000,
    autoPlay: true,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#3B82F6',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 60,
    channelListRefreshIntervalMinutes: 30,
    maxCachedEpgDays: 7,
  ),
);

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  final backend = MemoryBackend();
  final cache = CacheService(backend);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        crispyBackendProvider.overrideWithValue(backend),
        cacheServiceProvider.overrideWithValue(cache),
        settingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  });

  testWidgets('clipboard backup import shows shared confirmation dialog', (
    tester,
  ) async {
    await _pump(tester, const BackupSettingsSection());

    await tester.tap(find.text('Clipboard Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste from Clipboard'));
    await tester.pumpAndSettle();

    expect(find.text('Import Backup'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });

  testWidgets('settings import shows shared confirmation dialog', (
    tester,
  ) async {
    await _pump(tester, const SettingsImportExportSection());

    await tester.tap(find.text('Import Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Import Settings'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });
}
