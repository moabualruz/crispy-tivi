import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/cache_service.dart';
import '../core/data/crispy_backend.dart';
import 'app_config.dart';

/// Key used to store user overrides in the settings DB.
const _kUserOverridesKey = 'crispy_tivi_user_config_overrides';

/// Loads system config from assets and merges user overrides.
///
/// **System Config**: `assets/config/app_config.json`
/// **User Overrides**: Drift SQLite (via [CacheService])
class ConfigService {
  ConfigService({
    required this.assetLoader,
    required this.cacheService,
    required CrispyBackend backend,
  }) : _backend = backend;

  /// Abstraction for loading asset strings (testable).
  final Future<String> Function(String path) assetLoader;

  /// Cache service for persisted settings.
  final CacheService cacheService;

  /// Rust backend for algorithmic operations.
  final CrispyBackend _backend;

  AppConfig? _cachedConfig;

  /// Loads and returns the merged [AppConfig].
  ///
  /// 1. Reads `assets/config/app_config.json` (system defaults).
  /// 2. Reads user overrides from Drift DB.
  /// 3. Deep-merges user overrides on top of system defaults.
  /// 4. Parses into typed [AppConfig].
  Future<AppConfig> load() async {
    if (_cachedConfig != null) return _cachedConfig!;

    // 1. Load system config from assets.
    final systemJson = await assetLoader('assets/config/app_config.json');
    final systemMap = json.decode(systemJson) as Map<String, dynamic>;

    // 2. Load user overrides from Drift DB.
    final overridesJson = await cacheService.getSetting(_kUserOverridesKey);
    final overridesMap =
        overridesJson != null
            ? json.decode(overridesJson) as Map<String, dynamic>
            : <String, dynamic>{};

    // 3. Deep-merge via Rust backend (overrides win).
    final mergedJson = _backend.deepMergeJson(
      json.encode(systemMap),
      json.encode(overridesMap),
    );
    final merged = json.decode(mergedJson) as Map<String, dynamic>;

    // 4. Parse into typed model.
    _cachedConfig = AppConfig.fromJson(merged);
    return _cachedConfig!;
  }

  /// Saves a user override. Does NOT modify the asset file.
  Future<void> setOverride(String dotPath, dynamic value) async {
    final overridesJson = await cacheService.getSetting(_kUserOverridesKey);
    final overridesMap =
        overridesJson != null
            ? json.decode(overridesJson) as Map<String, dynamic>
            : <String, dynamic>{};

    final updatedJson = _backend.setNestedValue(
      json.encode(overridesMap),
      dotPath,
      json.encode(value),
    );
    await cacheService.setSetting(_kUserOverridesKey, updatedJson);

    // Invalidate cache so next load() re-merges.
    _cachedConfig = null;
  }

  /// Clears all user overrides, reverting to system defaults.
  Future<void> clearOverrides() async {
    await cacheService.removeSetting(_kUserOverridesKey);
    _cachedConfig = null;
  }
}

/// Riverpod provider for [ConfigService].
final configServiceProvider = FutureProvider<AppConfig>((ref) async {
  final cache = ref.read(cacheServiceProvider);
  final backend = ref.read(crispyBackendProvider);
  final service = ConfigService(
    assetLoader: rootBundle.loadString,
    cacheService: cache,
    backend: backend,
  );
  return service.load();
});
