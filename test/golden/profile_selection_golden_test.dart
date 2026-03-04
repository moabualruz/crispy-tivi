import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crispy_tivi/config/config_service.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/core/theme/app_theme.dart';
import 'package:crispy_tivi/core/theme/theme_provider.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';
import 'package:crispy_tivi/features/profiles/domain/entities/user_profile.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/dvr_permission.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/user_role.dart';
import 'package:crispy_tivi/features/profiles/presentation/screens/profile_selection_screen.dart';

const _testConfigJson = '''
{
  "appName": "CrispyTivi",
  "appVersion": "0.1.0-test",
  "api": {
    "baseUrl": "http://localhost",
    "backendPort": 8080,
    "connectTimeoutMs": 10000,
    "receiveTimeoutMs": 30000,
    "sendTimeoutMs": 10000
  },
  "player": {
    "defaultBufferDurationMs": 5000,
    "hwdecMode": "auto",
    "autoPlay": false,
    "defaultAspectRatio": "16:9",
    "afrEnabled": false,
    "afrLiveTv": true,
    "afrVod": true,
    "pipOnMinimize": true,
    "streamProfile": "auto",
    "recordingProfile": "original",
    "epgTimezone": "system",
    "audioOutput": "auto",
    "audioPassthroughEnabled": false,
    "audioPassthroughCodecs": ["ac3", "dts"]
  },
  "theme": {
    "mode": "dark",
    "seedColorHex": "#6750A4",
    "useDynamicColor": false
  },
  "features": {
    "iptvEnabled": true,
    "jellyfinEnabled": false,
    "plexEnabled": false,
    "embyEnabled": false
  },
  "cache": {
    "epgRefreshIntervalMinutes": 360,
    "channelListRefreshIntervalMinutes": 60,
    "maxCachedEpgDays": 7
  }
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppTheme.useGoogleFonts = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProfileSelectionScreen golden — single profile', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    const profiles = [
      UserProfile(
        id: 'default',
        name: 'Default',
        avatarIndex: 0,
        isActive: true,
        pinVersion: 1,
        role: UserRole.admin,
        dvrPermission: DvrPermission.full,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
          configServiceProvider.overrideWith((ref) async {
            final c = ref.read(cacheServiceProvider);
            final b = ref.read(crispyBackendProvider);
            final service = ConfigService(
              assetLoader: (_) async => _testConfigJson,
              cacheService: c,
              backend: b,
            );
            return service.load();
          }),
          profileServiceProvider.overrideWith(() {
            return _FakeProfileService(profiles);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const ProfileSelectionScreen(),
        ),
      ),
    );
    // Use explicit pump instead of pumpAndSettle — the ProfileSelectionScreen
    // has FocusWrapper animated scrolls + AnimatedSize that keep tickers alive.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(ProfileSelectionScreen),
      matchesGoldenFile('goldens/profile_selection_single.png'),
    );
  });

  testWidgets('ProfileSelectionScreen golden — multiple '
      'profiles', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testBackend = MemoryBackend();
    final testCache = CacheService(testBackend);

    const profiles = [
      UserProfile(
        id: 'admin',
        name: 'Admin',
        avatarIndex: 0,
        isActive: true,
        pinVersion: 1,
        role: UserRole.admin,
        dvrPermission: DvrPermission.full,
      ),
      UserProfile(
        id: 'viewer',
        name: 'Viewer',
        avatarIndex: 1,
        pinVersion: 1,
        role: UserRole.viewer,
        dvrPermission: DvrPermission.full,
      ),
      UserProfile(
        id: 'kids',
        name: 'Kids',
        avatarIndex: 2,
        isChild: true,
        maxAllowedRating: 2,
        pinVersion: 1,
        role: UserRole.viewer,
        dvrPermission: DvrPermission.viewOnly,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crispyBackendProvider.overrideWithValue(testBackend),
          cacheServiceProvider.overrideWithValue(testCache),
          configServiceProvider.overrideWith((ref) async {
            final c = ref.read(cacheServiceProvider);
            final b = ref.read(crispyBackendProvider);
            final service = ConfigService(
              assetLoader: (_) async => _testConfigJson,
              cacheService: c,
              backend: b,
            );
            return service.load();
          }),
          profileServiceProvider.overrideWith(() {
            return _FakeProfileService(profiles);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.fromThemeState(const ThemeState()).theme,
          home: const ProfileSelectionScreen(),
        ),
      ),
    );
    // Use explicit pump instead of pumpAndSettle — the ProfileSelectionScreen
    // has FocusWrapper animated scrolls + AnimatedSize that keep tickers alive.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(ProfileSelectionScreen),
      matchesGoldenFile(
        'goldens/'
        'profile_selection_multiple.png',
      ),
    );
  });
}

/// Fake profile service that returns fixed profiles.
class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._profiles);
  final List<UserProfile> _profiles;

  @override
  Future<ProfileState> build() async {
    return ProfileState(
      profiles: _profiles,
      activeProfileId: _profiles.first.id,
    );
  }
}
