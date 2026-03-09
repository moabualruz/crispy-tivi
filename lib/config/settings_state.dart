import 'dart:ui' show Color;

import 'app_config.dart';
import '../core/domain/entities/playlist_source.dart';
import '../features/player/data/shader_service.dart';
import '../features/player/presentation/widgets/screensaver_overlay.dart';
import '../features/settings/domain/entities/remote_action.dart';

/// Key for persisting playlist sources list.
const kSourcesKey = 'crispy_tivi_playlist_sources';

/// Key for persisting sync interval.
const kSyncIntervalKey = 'crispy_sync_interval_hours';

/// Key for persisting hidden category groups.
const kHiddenGroupsKey = 'crispy_hidden_groups';

/// Key for persisting notification preference.
const kNotificationsEnabledKey = 'crispy_notifications_enabled';

/// Key for persisting hidden channel IDs.
const kHiddenChannelIdsKey = 'crispy_hidden_channel_ids';

/// Key for persisting blocked channel IDs.
const kBlockedChannelIdsKey = 'crispy_blocked_channel_ids';

/// Key for persisting EPG assignment overrides.
const kEpgOverridesKey = 'crispy_epg_overrides';

/// Key for persisting remote control key mappings.
const kRemoteKeyMappingsKey = 'crispy_remote_key_mappings';

/// Key for persisting channel sort mode preference.
const kChannelSortModeKey = 'crispy_channel_sort_mode';

/// Key for persisting VOD sort option preference.
const kVodSortOptionKey = 'crispy_vod_sort_option';

/// Key for persisting channel view mode preference.
///
/// Values: the [ChannelViewMode] enum name strings.
const kChannelViewModeKey = 'crispy_channel_view_mode';

/// Key for persisting series sort option preference.
const kSeriesSortOptionKey = 'crispy_series_sort_option';

/// Key for persisting the VOD grid density preference.
///
/// Values: 'compact' | 'standard' | 'large'
const kVodGridDensityKey = 'crispy_vod_grid_density';

/// Key for persisting favorites list sort option.
///
/// Values: the [FavoritesSort] enum name strings.
const kFavoritesSortOptionKey = 'crispy_favorites_sort_option';

/// Key for persisting the history-recording paused toggle.
///
/// Values: 'true' | 'false' (default: 'false' — recording active).
const kHistoryRecordingPausedKey = 'crispy_history_recording_paused';

// ─────────────────────────────────────────────────────────────
//  FavoritesSort — sort order for personal lists
// ─────────────────────────────────────────────────────────────

/// Sort options for the favorites / personal lists tabs.
enum FavoritesSort {
  /// Most-recently added first (default).
  recentlyAdded,

  /// Alphabetical A → Z.
  nameAsc,

  /// Alphabetical Z → A.
  nameDesc,

  /// Grouped by content type (channel, movie, series, etc.).
  contentType;

  /// Human-readable label shown in the dropdown.
  String get label => switch (this) {
    FavoritesSort.recentlyAdded => 'Recently Added',
    FavoritesSort.nameAsc => 'A – Z',
    FavoritesSort.nameDesc => 'Z – A',
    FavoritesSort.contentType => 'Content Type',
  };
}

// ─────────────────────────────────────────────────────────────
//  ChannelViewMode — list vs grid display
// ─────────────────────────────────────────────────────────────

/// Display mode for the channel list.
enum ChannelViewMode {
  /// Traditional scrollable list (default).
  list,

  /// Responsive grid of channel logo tiles.
  grid;

  /// Human-readable label shown in tooltips.
  String get label => switch (this) {
    ChannelViewMode.list => 'List View',
    ChannelViewMode.grid => 'Grid View',
  };
}

/// Key for persisting global EPG URL.
const kGlobalEpgUrlKey = 'crispy_global_epg_url';

// ─────────────────────────────────────────────────────────────
//  Bandwidth / Data Usage keys
// ─────────────────────────────────────────────────────────────

/// Key for persisting global quality cap.
/// Values: 'auto' | 'sd' | 'hd' | '4k'
const kQualityCapKey = 'crispy_quality_cap';

/// Key for persisting cellular data limit toggle.
const kCellularDataLimitKey = 'crispy_cellular_data_limit';

/// Key for persisting data-saving mode toggle.
const kDataSavingModeKey = 'crispy_data_saving_mode';

// ─────────────────────────────────────────────────────────────
//  Notification preference keys
// ─────────────────────────────────────────────────────────────

/// Key for persisting recording-complete notification toggle.
const kNotifyRecordingCompleteKey = 'crispy_notify_recording_complete';

/// Key for persisting new-episode-available notification toggle.
const kNotifyNewEpisodeKey = 'crispy_notify_new_episode';

/// Key for persisting live-event-reminder notification toggle.
const kNotifyLiveEventKey = 'crispy_notify_live_event';

/// FE-S-07: Key for persisting EPG-update notification toggle.
const kNotifyEpgUpdateKey = 'crispy_notify_epg_update';

/// Key: default screen shown after profile selection.
/// Values: 'home' | 'live_tv'
const kDefaultScreenKey = 'crispy_default_screen';

/// Key: auto-resume last channel on Live TV startup.
/// Values: 'true' | 'false'
const kAutoResumeChannelKey = 'crispy_auto_resume_channel';

/// Key: last watched channel ID (persisted for resume).
const kLastChannelIdKey = 'crispy_last_channel_id';

/// Key: last watched group name (persisted for resume).
const kLastGroupNameKey = 'crispy_last_group_name';

/// Key: whether to auto-play the next episode after the
/// current one ends. Default: true (matches common streaming apps).
const kAutoplayNextEpisodeKey = 'crispy_autoplay_next_episode';

/// Key: allowed device orientations for the player (JSON array of
/// [DeviceOrientation] indices). Empty/absent = all orientations.
const kRotationLockKey = 'crispy_rotation_lock';

/// Key: whether to show a wall-clock finish time next to the remaining
/// duration on the VOD seek bar. Speed-aware, locale-aware. Default: true.
const kShowFinishTimeKey = 'crispy_show_finish_time';

/// Key for persisting the user's preferred locale (language code).
///
/// Values: null (system default), 'en', 'ar', 'de', 'es', 'fr', etc.
const kLocaleKey = 'crispy_locale';

// ─────────────────────────────────────────────────────────────
//  QualityCap — global stream quality ceiling
// ─────────────────────────────────────────────────────────────

/// Global quality cap options for the bandwidth section.
enum QualityCap {
  /// No cap — the player selects the best available stream.
  auto,

  /// Standard definition (≤ 480p).
  sd,

  /// High definition (≤ 1080p).
  hd,

  /// Ultra-high definition (≤ 2160p).
  uhd;

  /// Human-readable label shown in the dropdown.
  String get label => switch (this) {
    QualityCap.auto => 'Auto (No Cap)',
    QualityCap.sd => 'SD (≤ 480p)',
    QualityCap.hd => 'HD (≤ 1080p)',
    QualityCap.uhd => '4K (≤ 2160p)',
  };
}

/// Key for persisting the subtitle CC style as JSON.
const kSubtitleStyleKey = 'crispy_subtitle_cc_style';

// ─────────────────────────────────────────────────────────────
//  SubtitleStyle — immutable value object
// ─────────────────────────────────────────────────────────────

/// Subtitle font-size options.
enum SubtitleFontSize {
  small,
  medium,
  large,
  extraLarge;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleFontSize.small => 'Small',
    SubtitleFontSize.medium => 'Medium',
    SubtitleFontSize.large => 'Large',
    SubtitleFontSize.extraLarge => 'XL',
  };

  /// Actual font size in logical pixels.
  double get pixels => switch (this) {
    SubtitleFontSize.small => 14,
    SubtitleFontSize.medium => 18,
    SubtitleFontSize.large => 24,
    SubtitleFontSize.extraLarge => 32,
  };
}

/// Subtitle text-color presets.
enum SubtitleTextColor {
  white,
  yellow,
  green,
  cyan;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleTextColor.white => 'White',
    SubtitleTextColor.yellow => 'Yellow',
    SubtitleTextColor.green => 'Green',
    SubtitleTextColor.cyan => 'Cyan',
  };

  /// The concrete [Color] value.
  Color get color => switch (this) {
    SubtitleTextColor.white => const Color(0xFFFFFFFF),
    SubtitleTextColor.yellow => const Color(0xFFFFEA00),
    SubtitleTextColor.green => const Color(0xFF00E676),
    SubtitleTextColor.cyan => const Color(0xFF00E5FF),
  };
}

/// Subtitle background presets.
enum SubtitleBackground {
  black,
  semiTransparent,
  transparent;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleBackground.black => 'Black',
    SubtitleBackground.semiTransparent => 'Semi',
    SubtitleBackground.transparent => 'None',
  };

  /// The concrete [Color] value.
  Color get color => switch (this) {
    SubtitleBackground.black => const Color(0xFF000000),
    SubtitleBackground.semiTransparent => const Color(0x99000000),
    SubtitleBackground.transparent => const Color(0x00000000),
  };
}

/// Subtitle edge / shadow style.
enum SubtitleEdgeStyle {
  none,
  dropShadow,
  raised,
  depressed,
  outline;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleEdgeStyle.none => 'None',
    SubtitleEdgeStyle.dropShadow => 'Shadow',
    SubtitleEdgeStyle.raised => 'Raised',
    SubtitleEdgeStyle.depressed => 'Depressed',
    SubtitleEdgeStyle.outline => 'Outline',
  };
}

/// Subtitle outline color presets.
enum SubtitleOutlineColor {
  black,
  white,
  red,
  transparent;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleOutlineColor.black => 'Black',
    SubtitleOutlineColor.white => 'White',
    SubtitleOutlineColor.red => 'Red',
    SubtitleOutlineColor.transparent => 'None',
  };

  /// The concrete [Color] value.
  Color get color => switch (this) {
    SubtitleOutlineColor.black => const Color(0xFF000000),
    SubtitleOutlineColor.white => const Color(0xFFFFFFFF),
    SubtitleOutlineColor.red => const Color(0xFFFF0000),
    SubtitleOutlineColor.transparent => const Color(0x00000000),
  };
}

/// Immutable subtitle CC style configuration.
///
/// All fields have sensible defaults matching broadcast standards.
class SubtitleStyle {
  const SubtitleStyle({
    this.fontSize = SubtitleFontSize.medium,
    this.textColor = SubtitleTextColor.white,
    this.background = SubtitleBackground.semiTransparent,
    this.edgeStyle = SubtitleEdgeStyle.dropShadow,
    this.isBold = false,
    this.verticalPosition = 100,
    this.outlineColor = SubtitleOutlineColor.black,
    this.outlineSize = 2.0,
    this.backgroundOpacity = 0.6,
    this.hasShadow = true,
  });

  final SubtitleFontSize fontSize;
  final SubtitleTextColor textColor;
  final SubtitleBackground background;

  /// Legacy edge style — kept for backward-compatible deserialization.
  /// UI replaced by fine-grained outline/shadow controls.
  final SubtitleEdgeStyle edgeStyle;

  /// Whether subtitle text is bold.
  final bool isBold;

  /// Vertical position from top (0) to bottom (100).
  /// Default: 100 (bottom of screen). Maps to mpv `sub-pos`.
  final int verticalPosition;

  /// Outline (border) color around subtitle text.
  final SubtitleOutlineColor outlineColor;

  /// Outline thickness in pixels (0–10). Maps to mpv `sub-border-size`.
  final double outlineSize;

  /// Background box opacity (0.0 transparent – 1.0 opaque).
  final double backgroundOpacity;

  /// Whether to render a drop shadow behind text.
  final bool hasShadow;

  /// Default style matching broadcast CC standards.
  static const SubtitleStyle defaults = SubtitleStyle();

  SubtitleStyle copyWith({
    SubtitleFontSize? fontSize,
    SubtitleTextColor? textColor,
    SubtitleBackground? background,
    SubtitleEdgeStyle? edgeStyle,
    bool? isBold,
    int? verticalPosition,
    SubtitleOutlineColor? outlineColor,
    double? outlineSize,
    double? backgroundOpacity,
    bool? hasShadow,
  }) => SubtitleStyle(
    fontSize: fontSize ?? this.fontSize,
    textColor: textColor ?? this.textColor,
    background: background ?? this.background,
    edgeStyle: edgeStyle ?? this.edgeStyle,
    isBold: isBold ?? this.isBold,
    verticalPosition: verticalPosition ?? this.verticalPosition,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineSize: outlineSize ?? this.outlineSize,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    hasShadow: hasShadow ?? this.hasShadow,
  );

  /// Serialise to a JSON-compatible map for persistence.
  Map<String, dynamic> toJson() => {
    'fontSize': fontSize.name,
    'textColor': textColor.name,
    'background': background.name,
    'edgeStyle': edgeStyle.name,
    'isBold': isBold,
    'verticalPosition': verticalPosition,
    'outlineColor': outlineColor.name,
    'outlineSize': outlineSize,
    'backgroundOpacity': backgroundOpacity,
    'hasShadow': hasShadow,
  };

  /// Deserialise from a JSON-compatible map.
  ///
  /// Unknown values fall back to defaults so old stored data
  /// never causes crashes after an enum is extended.
  factory SubtitleStyle.fromJson(Map<String, dynamic> json) => SubtitleStyle(
    fontSize: SubtitleFontSize.values.firstWhere(
      (e) => e.name == json['fontSize'],
      orElse: () => SubtitleFontSize.medium,
    ),
    textColor: SubtitleTextColor.values.firstWhere(
      (e) => e.name == json['textColor'],
      orElse: () => SubtitleTextColor.white,
    ),
    background: SubtitleBackground.values.firstWhere(
      (e) => e.name == json['background'],
      orElse: () => SubtitleBackground.semiTransparent,
    ),
    edgeStyle: SubtitleEdgeStyle.values.firstWhere(
      (e) => e.name == json['edgeStyle'],
      orElse: () => SubtitleEdgeStyle.dropShadow,
    ),
    isBold: json['isBold'] as bool? ?? false,
    verticalPosition: json['verticalPosition'] as int? ?? 100,
    outlineColor: SubtitleOutlineColor.values.firstWhere(
      (e) => e.name == json['outlineColor'],
      orElse: () => SubtitleOutlineColor.black,
    ),
    outlineSize: (json['outlineSize'] as num?)?.toDouble() ?? 2.0,
    backgroundOpacity: (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.6,
    hasShadow: json['hasShadow'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is SubtitleStyle &&
      fontSize == other.fontSize &&
      textColor == other.textColor &&
      background == other.background &&
      edgeStyle == other.edgeStyle &&
      isBold == other.isBold &&
      verticalPosition == other.verticalPosition &&
      outlineColor == other.outlineColor &&
      outlineSize == other.outlineSize &&
      backgroundOpacity == other.backgroundOpacity &&
      hasShadow == other.hasShadow;

  @override
  int get hashCode => Object.hash(
    fontSize,
    textColor,
    background,
    edgeStyle,
    isBold,
    verticalPosition,
    outlineColor,
    outlineSize,
    backgroundOpacity,
    hasShadow,
  );
}

/// Reactive settings state.
class SettingsState {
  SettingsState({
    required this.config,
    this.sources = const [],
    this.syncIntervalHours = 24,
    this.hiddenGroups = const [],
    this.notificationsEnabled = true,
    this.hiddenChannelIds = const {},
    this.blockedChannelIds = const {},
    this.epgOverrides = const {},
    this.defaultScreen = 'home',
    this.autoResumeChannel = false,
    this.autoplayNextEpisode = true,
    this.subtitleStyle = SubtitleStyle.defaults,
    this.favoritesSortOption = FavoritesSort.recentlyAdded,
    Map<int, RemoteAction>? remoteKeyMap,
    this.qualityCap = QualityCap.auto,
    this.cellularDataLimitEnabled = false,
    this.dataSavingMode = false,
    this.notifyRecordingComplete = true,
    this.notifyNewEpisode = true,
    this.notifyLiveEvent = true,
    // FE-S-07: EPG update notification toggle.
    this.notifyEpgUpdate = false,
    this.channelViewMode = ChannelViewMode.list,
    this.historyRecordingPaused = false,
    this.screensaverMode = ScreensaverMode.bouncingLogo,
    this.screensaverTimeout = 0,
    this.shaderPresetId = 'none',
    this.locale,
  }) : remoteKeyMap = remoteKeyMap ?? defaultRemoteKeyMap;

  final AppConfig config;
  final List<PlaylistSource> sources;

  /// Sync interval in hours (default: 24).
  final int syncIntervalHours;

  /// Category groups hidden from channel/VOD lists.
  final List<String> hiddenGroups;

  /// Whether in-app notifications are enabled.
  final bool notificationsEnabled;

  /// Individual channel IDs hidden from lists.
  final Set<String> hiddenChannelIds;

  /// Individual channel IDs blocked
  /// (hidden + PIN to unblock).
  final Set<String> blockedChannelIds;

  /// Manual EPG assignment overrides.
  ///
  /// Key: channel ID, value: target channel ID whose
  /// EPG to use.
  final Map<String, String> epgOverrides;

  /// Default screen after profile selection.
  /// 'home' or 'live_tv'.
  final String defaultScreen;

  /// Whether to auto-resume last channel on Live TV.
  final bool autoResumeChannel;

  /// Whether to auto-play the next episode when the current
  /// one ends. Default: `true` (matches common streaming apps).
  final bool autoplayNextEpisode;

  /// User's CC / subtitle styling preferences.
  ///
  /// Persisted as JSON via [kSubtitleStyleKey].
  final SubtitleStyle subtitleStyle;

  /// Sort order for personal favorites / history lists.
  ///
  /// Persisted via [kFavoritesSortOptionKey].
  final FavoritesSort favoritesSortOption;

  /// Remote control key-to-action mappings.
  ///
  /// Key: [LogicalKeyboardKey.keyId],
  /// value: [RemoteAction].
  final Map<int, RemoteAction> remoteKeyMap;

  // ── Bandwidth / Data Usage ─────────────────────

  /// Global quality cap applied to all streams.
  ///
  /// Persisted via [kQualityCapKey].
  final QualityCap qualityCap;

  /// Whether to restrict streams on cellular
  /// connections (mobile only).
  ///
  /// Persisted via [kCellularDataLimitKey].
  final bool cellularDataLimitEnabled;

  /// Data-saving mode — prefers lower bitrate
  /// streams regardless of connection type.
  ///
  /// Persisted via [kDataSavingModeKey].
  final bool dataSavingMode;

  /// Display mode for the channel list (list vs grid).
  ///
  /// Persisted via [kChannelViewModeKey].
  final ChannelViewMode channelViewMode;

  // ── Notification Preferences ───────────────────

  /// Notify when a DVR recording completes.
  ///
  /// Persisted via [kNotifyRecordingCompleteKey].
  final bool notifyRecordingComplete;

  /// Notify when a new episode becomes available.
  ///
  /// Persisted via [kNotifyNewEpisodeKey].
  final bool notifyNewEpisode;

  /// Notify with a reminder before a live event.
  ///
  /// Persisted via [kNotifyLiveEventKey].
  final bool notifyLiveEvent;

  /// FE-S-07: Notify when the EPG data has been updated.
  ///
  /// Persisted via [kNotifyEpgUpdateKey].
  final bool notifyEpgUpdate;

  /// Whether watch-history recording is paused.
  ///
  /// When `true`, new entries are NOT added to
  /// recently-watched or continue-watching history.
  /// Persisted via [kHistoryRecordingPausedKey].
  final bool historyRecordingPaused;

  /// Screensaver display mode (bouncing logo, clock, black).
  ///
  /// Persisted via [kScreensaverModeKey].
  final ScreensaverMode screensaverMode;

  /// Screensaver idle timeout in minutes. 0 = disabled.
  ///
  /// Persisted via [kScreensaverTimeoutKey].
  final int screensaverTimeout;

  /// Active GPU shader preset ID. 'none' = disabled.
  ///
  /// Persisted via [kShaderPresetKey].
  final String shaderPresetId;

  /// User's preferred locale (language code).
  ///
  /// When `null`, the system locale is used.
  /// Persisted via [kLocaleKey].
  final String? locale;

  /// All channel IDs that should be excluded from
  /// display.
  Set<String> get allHiddenChannelIds => {
    ...hiddenChannelIds,
    ...blockedChannelIds,
  };

  SettingsState copyWith({
    AppConfig? config,
    List<PlaylistSource>? sources,
    int? syncIntervalHours,
    List<String>? hiddenGroups,
    bool? notificationsEnabled,
    Set<String>? hiddenChannelIds,
    Set<String>? blockedChannelIds,
    Map<String, String>? epgOverrides,
    String? defaultScreen,
    bool? autoResumeChannel,
    bool? autoplayNextEpisode,
    SubtitleStyle? subtitleStyle,
    FavoritesSort? favoritesSortOption,
    Map<int, RemoteAction>? remoteKeyMap,
    QualityCap? qualityCap,
    bool? cellularDataLimitEnabled,
    bool? dataSavingMode,
    bool? notifyRecordingComplete,
    bool? notifyNewEpisode,
    bool? notifyLiveEvent,
    bool? notifyEpgUpdate,
    ChannelViewMode? channelViewMode,
    bool? historyRecordingPaused,
    ScreensaverMode? screensaverMode,
    int? screensaverTimeout,
    String? shaderPresetId,
    String? locale,
  }) {
    return SettingsState(
      config: config ?? this.config,
      sources: sources ?? this.sources,
      syncIntervalHours: syncIntervalHours ?? this.syncIntervalHours,
      hiddenGroups: hiddenGroups ?? this.hiddenGroups,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hiddenChannelIds: hiddenChannelIds ?? this.hiddenChannelIds,
      blockedChannelIds: blockedChannelIds ?? this.blockedChannelIds,
      epgOverrides: epgOverrides ?? this.epgOverrides,
      defaultScreen: defaultScreen ?? this.defaultScreen,
      autoResumeChannel: autoResumeChannel ?? this.autoResumeChannel,
      autoplayNextEpisode: autoplayNextEpisode ?? this.autoplayNextEpisode,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      favoritesSortOption: favoritesSortOption ?? this.favoritesSortOption,
      remoteKeyMap: remoteKeyMap ?? this.remoteKeyMap,
      qualityCap: qualityCap ?? this.qualityCap,
      cellularDataLimitEnabled:
          cellularDataLimitEnabled ?? this.cellularDataLimitEnabled,
      dataSavingMode: dataSavingMode ?? this.dataSavingMode,
      notifyRecordingComplete:
          notifyRecordingComplete ?? this.notifyRecordingComplete,
      notifyNewEpisode: notifyNewEpisode ?? this.notifyNewEpisode,
      notifyLiveEvent: notifyLiveEvent ?? this.notifyLiveEvent,
      notifyEpgUpdate: notifyEpgUpdate ?? this.notifyEpgUpdate,
      channelViewMode: channelViewMode ?? this.channelViewMode,
      historyRecordingPaused:
          historyRecordingPaused ?? this.historyRecordingPaused,
      screensaverMode: screensaverMode ?? this.screensaverMode,
      screensaverTimeout: screensaverTimeout ?? this.screensaverTimeout,
      shaderPresetId: shaderPresetId ?? this.shaderPresetId,
      locale: locale ?? this.locale,
    );
  }
}
