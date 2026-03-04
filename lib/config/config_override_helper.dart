import 'config_service.dart';
import 'settings_state.dart';

/// Helper that wraps [ConfigService] to apply config
/// overrides and reload.
///
/// Reduces boilerplate in [SettingsNotifier] where many
/// methods follow the same pattern:
/// `setOverride(key, value)` then `reload()`.
class ConfigOverrideHelper {
  ConfigOverrideHelper(this._configService);

  final ConfigService _configService;

  /// Applies a config override and reloads.
  ///
  /// Returns the reloaded config wrapped in a new
  /// [SettingsState] using [currentSources].
  Future<SettingsState> applyAndReload(
    String key,
    Object? value, {
    required SettingsState? currentState,
  }) async {
    await _configService.setOverride(key, value);
    final config = await _configService.load();
    final sources = currentState?.sources ?? [];
    return SettingsState(config: config, sources: sources);
  }

  /// Applies a config override without reload.
  Future<void> setOverride(String key, Object? value) async {
    await _configService.setOverride(key, value);
  }

  /// Reloads config and returns fresh state.
  Future<SettingsState> reload({required SettingsState? currentState}) async {
    final config = await _configService.load();
    final sources = currentState?.sources ?? [];
    return SettingsState(config: config, sources: sources);
  }
}
