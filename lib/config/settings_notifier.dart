import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/cache_service.dart';
import '../core/domain/entities/playlist_source.dart';
import '../core/widgets/density_mode.dart';
import '../features/player/data/shader_service.dart';
import '../features/player/presentation/widgets/screensaver_overlay.dart';
import '../features/settings/domain/entities/remote_action.dart';
import 'config_override_helper.dart';
import 'config_service.dart';
import 'settings_persistence.dart';
import 'settings_state.dart';

/// Re-export [SettingsState] so existing imports of
/// `settings_notifier.dart` still resolve.
export 'settings_state.dart';

/// Manages all user-facing settings with persistence
/// via Drift.
class SettingsNotifier extends AsyncNotifier<SettingsState> {
  late CacheService _cache;
  late SettingsPersistence _persistence;
  late ConfigOverrideHelper _config;

  @override
  Future<SettingsState> build() async {
    _cache = ref.read(cacheServiceProvider);
    final configService = ConfigService(
      assetLoader: rootBundle.loadString,
      cacheService: _cache,
      backend: ref.read(crispyBackendProvider),
    );
    _persistence = SettingsPersistence(_cache);
    _config = ConfigOverrideHelper(configService);
    final config = await configService.load();
    var sources = await _cache.getSources();

    // ── One-time migration: JSON blob → db_sources ──
    if (sources.isEmpty) {
      final legacySources = await _persistence.loadSources();
      if (legacySources.isNotEmpty) {
        for (final s in legacySources) {
          await _cache.saveSource(s);
        }
        // Remove the old JSON blob.
        await _cache.removeSetting(kSourcesKey);
        sources = legacySources;
      }
    }
    final syncIntervalStr = await _cache.getSetting(kSyncIntervalKey);
    final syncInterval =
        syncIntervalStr != null ? int.tryParse(syncIntervalStr) ?? 24 : 24;
    final hiddenGroups = await _persistence.loadHiddenGroups();
    final notifStr = await _cache.getSetting(kNotificationsEnabledKey);
    final notifEnabled = notifStr != 'false';
    final hiddenChannelIds = await _persistence.loadStringSet(
      kHiddenChannelIdsKey,
    );
    final blockedChannelIds = await _persistence.loadStringSet(
      kBlockedChannelIdsKey,
    );
    final epgOverrides = await _persistence.loadStringMap(kEpgOverridesKey);
    final remoteKeyMap = await _persistence.loadRemoteKeyMap();
    final defaultScreen = await _cache.getSetting(kDefaultScreenKey) ?? 'home';
    final autoResumeStr = await _cache.getSetting(kAutoResumeChannelKey);
    final autoResume = autoResumeStr == 'true';
    final autoplayNextStr = await _cache.getSetting(kAutoplayNextEpisodeKey);
    // Default is true — only false when explicitly stored as 'false'.
    final autoplayNext = autoplayNextStr != 'false';
    final subtitleStyleJson = await _cache.getSetting(kSubtitleStyleKey);
    final subtitleStyle =
        subtitleStyleJson != null
            ? SubtitleStyle.fromJson(
              Map<String, dynamic>.from(jsonDecode(subtitleStyleJson) as Map),
            )
            : SubtitleStyle.defaults;
    final favSortStr = await _cache.getSetting(kFavoritesSortOptionKey);
    final favoritesSortOption =
        favSortStr != null
            ? FavoritesSort.values.firstWhere(
              (e) => e.name == favSortStr,
              orElse: () => FavoritesSort.recentlyAdded,
            )
            : FavoritesSort.recentlyAdded;

    // ── Bandwidth ──
    final qualityCapStr = await _cache.getSetting(kQualityCapKey);
    final qualityCap =
        qualityCapStr != null
            ? QualityCap.values.firstWhere(
              (e) => e.name == qualityCapStr,
              orElse: () => QualityCap.auto,
            )
            : QualityCap.auto;
    final cellularStr = await _cache.getSetting(kCellularDataLimitKey);
    final cellularDataLimitEnabled = cellularStr == 'true';
    final dataSavingStr = await _cache.getSetting(kDataSavingModeKey);
    final dataSavingMode = dataSavingStr == 'true';

    // ── Notification Preferences ──
    final notifyRecStr = await _cache.getSetting(kNotifyRecordingCompleteKey);
    final notifyRecordingComplete = notifyRecStr != 'false';
    final notifyEpStr = await _cache.getSetting(kNotifyNewEpisodeKey);
    final notifyNewEpisode = notifyEpStr != 'false';
    final notifyLiveStr = await _cache.getSetting(kNotifyLiveEventKey);
    final notifyLiveEvent = notifyLiveStr != 'false';
    // FE-S-07: EPG update notification (default: false).
    final notifyEpgStr = await _cache.getSetting(kNotifyEpgUpdateKey);
    final notifyEpgUpdate = notifyEpgStr == 'true';

    // ── Channel View Mode ──
    final channelViewModeStr = await _cache.getSetting(kChannelViewModeKey);
    final channelViewMode =
        channelViewModeStr != null
            ? ChannelViewMode.values.firstWhere(
              (e) => e.name == channelViewModeStr,
              orElse: () => ChannelViewMode.list,
            )
            : ChannelViewMode.list;

    // ── History Recording ──
    final histPausedStr = await _cache.getSetting(kHistoryRecordingPausedKey);
    final historyRecordingPaused = histPausedStr == 'true';

    // ── Screensaver ──
    final ssModeName = await _cache.getSetting(kScreensaverModeKey);
    final screensaverMode =
        ssModeName != null
            ? ScreensaverMode.values.firstWhere(
              (e) => e.name == ssModeName,
              orElse: () => ScreensaverMode.bouncingLogo,
            )
            : ScreensaverMode.bouncingLogo;
    final ssTimeoutStr = await _cache.getSetting(kScreensaverTimeoutKey);
    final screensaverTimeout =
        ssTimeoutStr != null ? int.tryParse(ssTimeoutStr) ?? 0 : 0;

    // ── Shader Preset ──
    final shaderPresetId = await _cache.getSetting(kShaderPresetKey) ?? 'none';

    // ── Grid Density ──
    final gridDensityStr = await _cache.getSetting(kGridDensityKey);
    final gridDensity =
        gridDensityStr != null
            ? DensityMode.values.firstWhere(
              (e) => e.name == gridDensityStr,
              orElse: () => DensityMode.comfortable,
            )
            : DensityMode.comfortable;
    final spoilerBlurStr = await _cache.getSetting(kSpoilerBlurEnabledKey);
    final spoilerBlurEnabled = spoilerBlurStr == 'true';
    final vodDisplayModeStr = await _cache.getSetting(kVodDisplayModeKey);
    final vodDisplayMode =
        vodDisplayModeStr != null
            ? VodDisplayMode.values.firstWhere(
              (e) => e.name == vodDisplayModeStr,
              orElse: () => VodDisplayMode.poster,
            )
            : VodDisplayMode.poster;

    // ── Locale ──
    final locale = await _cache.getSetting(kLocaleKey);

    return SettingsState(
      config: config,
      sources: sources,
      syncIntervalHours: syncInterval,
      hiddenGroups: hiddenGroups,
      notificationsEnabled: notifEnabled,
      hiddenChannelIds: hiddenChannelIds,
      blockedChannelIds: blockedChannelIds,
      epgOverrides: epgOverrides,
      defaultScreen: defaultScreen,
      autoResumeChannel: autoResume,
      autoplayNextEpisode: autoplayNext,
      subtitleStyle: subtitleStyle,
      favoritesSortOption: favoritesSortOption,
      remoteKeyMap: remoteKeyMap,
      qualityCap: qualityCap,
      cellularDataLimitEnabled: cellularDataLimitEnabled,
      dataSavingMode: dataSavingMode,
      notifyRecordingComplete: notifyRecordingComplete,
      notifyNewEpisode: notifyNewEpisode,
      notifyLiveEvent: notifyLiveEvent,
      notifyEpgUpdate: notifyEpgUpdate,
      channelViewMode: channelViewMode,
      historyRecordingPaused: historyRecordingPaused,
      screensaverMode: screensaverMode,
      screensaverTimeout: screensaverTimeout,
      shaderPresetId: shaderPresetId,
      gridDensity: gridDensity,
      spoilerBlurEnabled: spoilerBlurEnabled,
      vodDisplayMode: vodDisplayMode,
      locale: locale,
    );
  }

  /// Applies a config override and emits the
  /// reloaded state.
  Future<void> _applyOverride(String key, Object? value) async {
    final newState = await _config.applyAndReload(
      key,
      value,
      currentState: state.value,
    );
    state = AsyncData(newState);
  }

  // ── Theme ──

  Future<void> setThemeMode(String mode) => _applyOverride('theme.mode', mode);

  Future<void> setSeedColor(String hex) =>
      _applyOverride('theme.seedColorHex', hex);

  // ── Player ──

  /// Set the hardware decoder mode.
  Future<void> setHwdecMode(String mode) =>
      _applyOverride('player.hwdecMode', mode);

  Future<void> setAspectRatio(String ratio) =>
      _applyOverride('player.defaultAspectRatio', ratio);

  // ── Auto Frame Rate (AFR) ──

  /// Enable or disable Auto Frame Rate globally.
  Future<void> setAfrEnabled(bool enabled) =>
      _applyOverride('player.afrEnabled', enabled);

  /// Enable or disable AFR for Live TV content.
  Future<void> setAfrLiveTv(bool enabled) =>
      _applyOverride('player.afrLiveTv', enabled);

  /// Enable or disable AFR for VOD content.
  Future<void> setAfrVod(bool enabled) =>
      _applyOverride('player.afrVod', enabled);

  // ── Picture-in-Picture ──

  /// Enable or disable auto PiP when minimized.
  Future<void> setPipOnMinimize(bool enabled) =>
      _applyOverride('player.pipOnMinimize', enabled);

  // ── Stream Profile ──

  /// Set the stream quality profile.
  Future<void> setStreamProfile(String profile) =>
      _applyOverride('player.streamProfile', profile);

  // ── Recording Profile ──

  /// Set the recording quality profile.
  Future<void> setRecordingProfile(String profile) =>
      _applyOverride('player.recordingProfile', profile);

  // ── EPG Timezone ──

  /// Set the EPG display timezone.
  Future<void> setEpgTimezone(String timezone) =>
      _applyOverride('player.epgTimezone', timezone);

  // ── Audio Output ──

  /// Set the audio output driver.
  Future<void> setAudioOutput(String output) =>
      _applyOverride('player.audioOutput', output);

  /// Enable or disable audio passthrough.
  Future<void> setAudioPassthroughEnabled(bool enabled) =>
      _applyOverride('player.audioPassthroughEnabled', enabled);

  /// Set the list of codecs to passthrough.
  Future<void> setAudioPassthroughCodecs(List<String> codecs) =>
      _applyOverride('player.audioPassthroughCodecs', codecs);

  // ── Loudness / Downmix ──

  /// Enable or disable EBU R128 loudness normalization.
  Future<void> setLoudnessNormalization(bool enabled) =>
      _applyOverride('player.loudnessNormalization', enabled);

  /// Enable or disable surround-to-stereo downmix.
  Future<void> setStereoDownmix(bool enabled) =>
      _applyOverride('player.stereoDownmix', enabled);

  // ── Video Upscaling ──

  /// Enable or disable video upscaling globally.
  Future<void> setUpscaleEnabled(bool enabled) =>
      _applyOverride('player.upscaleEnabled', enabled);

  /// Set the video upscaling mode.
  Future<void> setUpscaleMode(String mode) =>
      _applyOverride('player.upscaleMode', mode);

  /// Set the video upscaling quality preset.
  Future<void> setUpscaleQuality(String quality) =>
      _applyOverride('player.upscaleQuality', quality);

  // ── Focus Loss ──

  /// Enable or disable pause-on-focus-loss.
  Future<void> setPauseOnFocusLoss(bool enabled) =>
      _applyOverride('player.pauseOnFocusLoss', enabled);

  // ── External Player ──

  /// Set the external player preference.
  Future<void> setExternalPlayer(String player) =>
      _applyOverride('player.externalPlayer', player);

  // ── Skip Buttons (FE-PS-03) ──

  /// Show or hide Skip Intro / Skip Credits buttons
  /// during VOD playback.
  Future<void> setShowSkipButtons(bool enabled) =>
      _applyOverride('player.showSkipButtons', enabled);

  /// Set per-type segment skip config (JSON-encoded string).
  Future<void> setSegmentSkipConfig(String config) =>
      _applyOverride('player.segmentSkipConfig', config);

  /// Set the next-up overlay trigger mode.
  ///
  /// Values: 'off', 'static', 'smart'.
  Future<void> setNextUpMode(String mode) =>
      _applyOverride('player.nextUpMode', mode);

  // ── Max Volume ──

  /// Set the maximum volume percentage (100–300).
  Future<void> setMaxVolume(int value) =>
      _applyOverride('player.maxVolume', value.clamp(100, 300));

  // ── Seek Step (PS-09) ──

  /// Set the seek step duration in seconds.
  ///
  /// Valid values: 5, 10, 15, 20, 30.
  Future<void> setSeekStepSeconds(int seconds) =>
      _applyOverride('player.seekStepSeconds', seconds);

  // ── Deinterlace Mode (PS-14) ──

  /// Set the deinterlace mode for live TV.
  ///
  /// Values: 'off' (disabled) or 'auto' (media_kit auto-detect).
  Future<void> setDeinterlaceMode(String mode) =>
      _applyOverride('player.deinterlaceMode', mode);

  // ── Screensaver ──

  /// Set the screensaver display mode.
  Future<void> setScreensaverMode(ScreensaverMode mode) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kScreensaverModeKey, mode.name);
    state = AsyncData(current.copyWith(screensaverMode: mode));
  }

  /// Set the screensaver idle timeout in minutes. 0 = disabled.
  Future<void> setScreensaverTimeout(int minutes) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kScreensaverTimeoutKey, minutes.toString());
    state = AsyncData(current.copyWith(screensaverTimeout: minutes));
  }

  // ── Shader Preset ──

  /// Set the active GPU shader preset.
  Future<void> setShaderPreset(String presetId) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kShaderPresetKey, presetId);
    state = AsyncData(current.copyWith(shaderPresetId: presetId));
  }

  // ── Locale ──

  /// Set the user's preferred locale (language code).
  ///
  /// Pass `null` to revert to system default.
  Future<void> setLocale(String? languageCode) async {
    final current = state.value;
    if (current == null) return;
    if (languageCode != null) {
      await _cache.setSetting(kLocaleKey, languageCode);
    } else {
      await _cache.removeSetting(kLocaleKey);
    }
    state = AsyncData(current.copyWith(locale: languageCode));
  }

  // ── Sync ──

  Future<void> setSyncInterval(int hours) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kSyncIntervalKey, hours.toString());
    state = AsyncData(current.copyWith(syncIntervalHours: hours));
  }

  // ── Playlist Sources ──

  Future<void> addSource(PlaylistSource source) async {
    final current = state.value;
    if (current == null) return;
    await _cache.saveSource(source);
    final upd = [...current.sources, source];
    state = AsyncData(current.copyWith(sources: upd));
  }

  Future<void> removeSource(String id) async {
    final current = state.value;
    if (current == null) return;
    await _cache.deleteSource(id);
    final upd = current.sources.where((s) => s.id != id).toList();
    state = AsyncData(current.copyWith(sources: upd));
  }

  /// Reorders sources by moving the item at [oldIndex] to [newIndex].
  ///
  /// Follows the [ReorderableListView] convention where [newIndex]
  /// is the position *before* the removed item is inserted, so when
  /// moving an item downward the index is decremented by one.
  Future<void> reorderSources(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;
    final sources = [...current.sources];
    if (oldIndex < 0 || oldIndex >= sources.length) return;
    // ReorderableListView convention: adjust newIndex when moving down.
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNew < 0 || adjustedNew >= sources.length) return;
    final item = sources.removeAt(oldIndex);
    sources.insert(adjustedNew, item);
    final ids = sources.map((s) => s.id).toList();
    await _cache.reorderSources(ids);
    state = AsyncData(current.copyWith(sources: sources));
  }

  /// Replaces a source by ID with updated fields.
  Future<void> updateSource(PlaylistSource updated) async {
    final current = state.value;
    if (current == null) return;
    await _cache.saveSource(updated);
    final upd =
        current.sources.map((s) => s.id == updated.id ? updated : s).toList();
    state = AsyncData(current.copyWith(sources: upd));
  }

  /// Update user agent for a specific source.
  Future<void> updateSourceUserAgent(String sourceId, String? userAgent) async {
    final current = state.value;
    if (current == null) return;
    final updated =
        current.sources.map((s) {
          if (s.id == sourceId) {
            return s.copyWith(userAgent: userAgent);
          }
          return s;
        }).toList();
    // Persist the updated source.
    final src = updated.firstWhere((s) => s.id == sourceId);
    await _cache.saveSource(src);
    state = AsyncData(current.copyWith(sources: updated));
  }

  // ── Hidden Groups ──

  Future<void> setHiddenGroups(List<String> groups) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kHiddenGroupsKey, jsonEncode(groups));
    state = AsyncData(current.copyWith(hiddenGroups: groups));
  }

  Future<void> toggleHiddenGroup(String group) async {
    final current = state.value;
    if (current == null) return;
    final cur = current.hiddenGroups;
    final upd =
        cur.contains(group)
            ? cur.where((g) => g != group).toList()
            : [...cur, group];
    await setHiddenGroups(upd);
  }

  // ── Hidden/Blocked Channels ──

  /// Hides a channel from all lists.
  Future<void> hideChannel(String channelId) async {
    final current = state.value;
    if (current == null) return;
    final upd = {...current.hiddenChannelIds, channelId};
    await _persistence.saveStringSet(kHiddenChannelIdsKey, upd);
    state = AsyncData(current.copyWith(hiddenChannelIds: upd));
  }

  /// Unhides a previously hidden channel.
  Future<void> unhideChannel(String channelId) async {
    final current = state.value;
    if (current == null) return;
    final upd = current.hiddenChannelIds.where((id) => id != channelId).toSet();
    await _persistence.saveStringSet(kHiddenChannelIdsKey, upd);
    state = AsyncData(current.copyWith(hiddenChannelIds: upd));
  }

  /// Blocks a channel (hidden + PIN to unblock).
  Future<void> blockChannel(String channelId) async {
    final current = state.value;
    if (current == null) return;
    final upd = {...current.blockedChannelIds, channelId};
    await _persistence.saveStringSet(kBlockedChannelIdsKey, upd);
    state = AsyncData(current.copyWith(blockedChannelIds: upd));
  }

  /// Unblocks a previously blocked channel.
  Future<void> unblockChannel(String channelId) async {
    final current = state.value;
    if (current == null) return;
    final upd =
        current.blockedChannelIds.where((id) => id != channelId).toSet();
    await _persistence.saveStringSet(kBlockedChannelIdsKey, upd);
    state = AsyncData(current.copyWith(blockedChannelIds: upd));
  }

  // ── EPG Overrides ──

  /// Assigns a manual EPG source to a channel.
  Future<void> setEpgOverride(String channelId, String targetChannelId) async {
    final current = state.value;
    if (current == null) return;
    final upd = {...current.epgOverrides, channelId: targetChannelId};
    await _persistence.saveStringMap(kEpgOverridesKey, upd);
    state = AsyncData(current.copyWith(epgOverrides: upd));
  }

  /// Removes a manual EPG assignment.
  Future<void> clearEpgOverride(String channelId) async {
    final current = state.value;
    if (current == null) return;
    final upd = Map<String, String>.from(current.epgOverrides)
      ..remove(channelId);
    await _persistence.saveStringMap(kEpgOverridesKey, upd);
    state = AsyncData(current.copyWith(epgOverrides: upd));
  }

  // ── Remote Key Mappings ──

  /// Assigns a key to a remote action.
  Future<void> setRemoteKeyMapping(int keyId, RemoteAction action) async {
    final current = state.value;
    if (current == null) return;
    final upd = {...current.remoteKeyMap, keyId: action};
    await _persistence.saveRemoteKeyMap(upd);
    state = AsyncData(current.copyWith(remoteKeyMap: upd));
  }

  /// Removes a key mapping.
  Future<void> removeRemoteKeyMapping(int keyId) async {
    final current = state.value;
    if (current == null) return;
    final upd = Map<int, RemoteAction>.from(current.remoteKeyMap)
      ..remove(keyId);
    await _persistence.saveRemoteKeyMap(upd);
    state = AsyncData(current.copyWith(remoteKeyMap: upd));
  }

  /// Resets all key mappings to defaults.
  Future<void> resetRemoteKeyMappings() async {
    final current = state.value;
    if (current == null) return;
    await _persistence.saveRemoteKeyMap(defaultRemoteKeyMap);
    state = AsyncData(current.copyWith(remoteKeyMap: defaultRemoteKeyMap));
  }

  // ── Sort Preferences ──

  /// Persist the channel sort mode.
  Future<void> setChannelSortMode(String mode) =>
      _cache.setSetting(kChannelSortModeKey, mode);

  /// Load the persisted channel sort mode.
  Future<String?> getChannelSortMode() =>
      _cache.getSetting(kChannelSortModeKey);

  /// Persist the VOD sort option.
  Future<void> setVodSortOption(String option) =>
      _cache.setSetting(kVodSortOptionKey, option);

  /// Load the persisted VOD sort option.
  Future<String?> getVodSortOption() => _cache.getSetting(kVodSortOptionKey);

  /// Persist the series sort option.
  Future<void> setSeriesSortOption(String opt) =>
      _cache.setSetting(kSeriesSortOptionKey, opt);

  /// Load the persisted series sort option.
  Future<String?> getSeriesSortOption() =>
      _cache.getSetting(kSeriesSortOptionKey);

  /// Persist the VOD grid density preference.
  ///
  /// [density] must be one of 'compact', 'standard', or 'large'.
  Future<void> setVodGridDensity(String density) =>
      _cache.setSetting(kVodGridDensityKey, density);

  /// Load the persisted VOD grid density preference.
  ///
  /// Returns `null` when no preference has been saved yet.
  Future<String?> getVodGridDensity() => _cache.getSetting(kVodGridDensityKey);

  /// Persist and apply the favorites list sort preference.
  Future<void> setFavoritesSortOption(FavoritesSort option) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kFavoritesSortOptionKey, option.name);
    state = AsyncData(current.copyWith(favoritesSortOption: option));
  }

  // ── Image Auto-Fetch ──

  /// Set the TMDb API key for poster lookups.
  Future<void> setTmdbApiKey(String? key) =>
      _applyOverride('images.tmdbApiKey', key);

  // ── Notifications ──

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kNotificationsEnabledKey, enabled.toString());
    state = AsyncData(current.copyWith(notificationsEnabled: enabled));
  }

  // ── Live TV ──

  /// Set the default screen after profile selection.
  Future<void> setDefaultScreen(String screen) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kDefaultScreenKey, screen);
    state = AsyncData(current.copyWith(defaultScreen: screen));
  }

  /// Enable or disable auto-resume of last channel.
  Future<void> setAutoResumeChannel(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kAutoResumeChannelKey, enabled.toString());
    state = AsyncData(current.copyWith(autoResumeChannel: enabled));
  }

  /// Enable or disable auto-play of the next episode.
  Future<void> setAutoplayNextEpisode(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kAutoplayNextEpisodeKey, enabled.toString());
    state = AsyncData(current.copyWith(autoplayNextEpisode: enabled));
  }

  // ── Channel View Mode ──

  /// Persist and apply the channel view mode preference.
  Future<void> setChannelViewMode(ChannelViewMode mode) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kChannelViewModeKey, mode.name);
    state = AsyncData(current.copyWith(channelViewMode: mode));
  }

  // ── Grid Density & Visual Polish ──

  /// Persist and apply the grid density mode.
  Future<void> setGridDensity(DensityMode mode) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kGridDensityKey, mode.name);
    state = AsyncData(current.copyWith(gridDensity: mode));
  }

  /// Toggle spoiler blur for unwatched episode thumbnails.
  Future<void> setSpoilerBlurEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kSpoilerBlurEnabledKey, enabled.toString());
    state = AsyncData(current.copyWith(spoilerBlurEnabled: enabled));
  }

  /// Persist and apply the VOD display mode (poster/banner).
  Future<void> setVodDisplayMode(VodDisplayMode mode) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kVodDisplayModeKey, mode.name);
    state = AsyncData(current.copyWith(vodDisplayMode: mode));
  }

  // ── History Recording (FE-FAV-05) ──

  /// Toggle whether watch-history recording is paused.
  ///
  /// When paused, [FavoritesHistoryService] skips recording new
  /// entries until the user resumes.
  Future<void> setHistoryRecordingPaused(bool paused) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kHistoryRecordingPausedKey, paused.toString());
    state = AsyncData(current.copyWith(historyRecordingPaused: paused));
  }

  // ── Subtitle CC Style (FE-PS-05) ──

  /// Persist a new [SubtitleStyle] and emit updated state.
  Future<void> setSubtitleStyle(SubtitleStyle style) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kSubtitleStyleKey, jsonEncode(style.toJson()));
    state = AsyncData(current.copyWith(subtitleStyle: style));
  }

  /// Reset subtitle style to factory defaults.
  Future<void> resetSubtitleStyle() => setSubtitleStyle(SubtitleStyle.defaults);

  /// Persist the last-watched channel ID and group atomically.
  Future<void> setLastChannel(String? channelId, String? groupName) async {
    await _cache.setSetting(kLastChannelIdKey, channelId ?? '');
    await _cache.setSetting(kLastGroupNameKey, groupName ?? '');
  }

  /// Persist the last-watched channel ID.
  Future<void> setLastChannelId(String? id) =>
      _cache.setSetting(kLastChannelIdKey, id ?? '');

  /// Load the last-watched channel ID.
  Future<String?> getLastChannelId() async {
    final v = await _cache.getSetting(kLastChannelIdKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Persist the last-watched group name.
  Future<void> setLastGroupName(String? name) =>
      _cache.setSetting(kLastGroupNameKey, name ?? '');

  /// Load the last-watched group name.
  Future<String?> getLastGroupName() async {
    final v = await _cache.getSetting(kLastGroupNameKey);
    return (v == null || v.isEmpty) ? null : v;
  }

  // ── Bandwidth / Data Usage ─────────────────────────────────

  /// Set the global quality cap.
  Future<void> setQualityCap(QualityCap cap) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kQualityCapKey, cap.name);
    state = AsyncData(current.copyWith(qualityCap: cap));
  }

  /// Toggle the cellular data limit.
  Future<void> setCellularDataLimitEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kCellularDataLimitKey, enabled.toString());
    state = AsyncData(current.copyWith(cellularDataLimitEnabled: enabled));
  }

  /// Toggle data-saving mode.
  Future<void> setDataSavingMode(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kDataSavingModeKey, enabled.toString());
    state = AsyncData(current.copyWith(dataSavingMode: enabled));
  }

  // ── Notification Preferences ───────────────────────────────

  /// Toggle recording-complete notifications.
  Future<void> setNotifyRecordingComplete(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kNotifyRecordingCompleteKey, enabled.toString());
    state = AsyncData(current.copyWith(notifyRecordingComplete: enabled));
  }

  /// Toggle new-episode-available notifications.
  Future<void> setNotifyNewEpisode(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kNotifyNewEpisodeKey, enabled.toString());
    state = AsyncData(current.copyWith(notifyNewEpisode: enabled));
  }

  /// Toggle live-event-reminder notifications.
  Future<void> setNotifyLiveEvent(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kNotifyLiveEventKey, enabled.toString());
    state = AsyncData(current.copyWith(notifyLiveEvent: enabled));
  }

  /// FE-S-07: Toggle EPG-update notifications.
  Future<void> setNotifyEpgUpdate(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    await _cache.setSetting(kNotifyEpgUpdateKey, enabled.toString());
    state = AsyncData(current.copyWith(notifyEpgUpdate: enabled));
  }

  // ── Reset per Section (FE-S-03) ───────────────────────────

  /// Resets a named settings section to factory defaults.
  ///
  /// Recognised [section] values:
  /// - `'playback'` — clears all player config overrides.
  /// - `'notifications'` — resets all notification toggles.
  /// - `'bandwidth'` — resets quality cap and data toggles.
  /// - `'appearance'` — resets theme to system defaults.
  /// - `'liveTV'` — resets Live TV–specific prefs.
  Future<void> resetSection(String section) async {
    switch (section) {
      case 'playback':
        await setHwdecMode('auto');
        await setAspectRatio('16:9');
        await setStreamProfile('auto');
        await setRecordingProfile('original');
        await setAfrEnabled(false);
        await setPipOnMinimize(true);
        await setExternalPlayer('none');
        await setSeekStepSeconds(10);
        await setDeinterlaceMode('off');
        await setAudioPassthroughEnabled(false);
        await setLoudnessNormalization(true);
        await setStereoDownmix(false);
        await setShowSkipButtons(true);
        await setSegmentSkipConfig('');
        await setNextUpMode('static');
        await resetSubtitleStyle();
      case 'notifications':
        await setNotificationsEnabled(true);
        await setNotifyRecordingComplete(true);
        await setNotifyNewEpisode(true);
        await setNotifyLiveEvent(true);
        // FE-S-07: reset EPG update notification (default: off).
        await setNotifyEpgUpdate(false);
      case 'bandwidth':
        await setQualityCap(QualityCap.auto);
        await setCellularDataLimitEnabled(false);
        await setDataSavingMode(false);
      case 'appearance':
        await setThemeMode('system');
      case 'liveTV':
        await setDefaultScreen('home');
        await setAutoResumeChannel(false);
        await setAutoplayNextEpisode(true);
    }
  }
}

/// Global settings provider.
final settingsNotifierProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(
      SettingsNotifier.new,
    );
