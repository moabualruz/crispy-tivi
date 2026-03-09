import 'package:json_annotation/json_annotation.dart';

part 'app_config.g.dart';

/// Root application configuration.
///
/// Loaded from `assets/config/app_config.json` at startup.
/// All values are overridable via [UserConfig] (SharedPrefs).
@JsonSerializable(explicitToJson: true)
class AppConfig {
  const AppConfig({
    required this.appName,
    required this.appVersion,
    required this.api,
    required this.player,
    required this.theme,
    required this.features,
    required this.cache,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);

  final String appName;
  final String appVersion;
  final ApiConfig api;
  final PlayerConfig player;
  final ThemeConfig theme;
  final FeaturesConfig features;
  final CacheConfig cache;

  Map<String, dynamic> toJson() => _$AppConfigToJson(this);
}

@JsonSerializable()
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.backendPort,
    required this.connectTimeoutMs,
    required this.receiveTimeoutMs,
    required this.sendTimeoutMs,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> json) =>
      _$ApiConfigFromJson(json);

  final String baseUrl;
  final int backendPort;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;
  final int sendTimeoutMs;

  Map<String, dynamic> toJson() => _$ApiConfigToJson(this);
}

@JsonSerializable()
class PlayerConfig {
  const PlayerConfig({
    required this.defaultBufferDurationMs,
    required this.autoPlay,
    required this.defaultAspectRatio,
    this.hwdecMode = 'auto',
    this.afrEnabled = false,
    this.afrLiveTv = true,
    this.afrVod = true,
    this.pipOnMinimize = true,
    this.streamProfile = 'auto',
    this.recordingProfile = 'original',
    this.epgTimezone = 'system',
    this.audioOutput = 'auto',
    this.audioPassthroughEnabled = false,
    this.audioPassthroughCodecs = const ['ac3', 'dts'],
    this.externalPlayer = 'none',
    this.pauseOnFocusLoss = false,
    this.upscaleEnabled = false,
    this.upscaleMode = 'auto',
    this.upscaleQuality = 'balanced',
    this.seekStepSeconds = 10,
    this.deinterlaceMode = 'off',
    // FE-PS-03: Skip Intro / Credits buttons
    this.showSkipButtons = true,
    this.loudnessNormalization = true,
    this.stereoDownmix = false,
    this.segmentSkipConfig = '',
    this.nextUpMode = 'static',
    this.maxVolume = 100,
  });

  factory PlayerConfig.fromJson(Map<String, dynamic> json) =>
      _$PlayerConfigFromJson(json);

  final int defaultBufferDurationMs;
  final bool autoPlay;
  final String defaultAspectRatio;

  /// Hardware decoder mode: 'auto', 'no', 'nvdec', 'd3d11va', etc.
  ///
  /// See [HardwareDecoder] enum for all valid values.
  final String hwdecMode;

  /// Auto Frame Rate (AFR) - match display refresh to video FPS.
  final bool afrEnabled;

  /// Apply AFR for Live TV content.
  final bool afrLiveTv;

  /// Apply AFR for VOD content (movies/series).
  final bool afrVod;

  /// Automatically enter Picture-in-Picture when app is minimized.
  final bool pipOnMinimize;

  /// Stream quality profile: 'auto', 'low', 'medium', 'high', 'maximum'.
  final String streamProfile;

  /// Recording quality profile: 'original', 'high', 'medium', 'low'.
  final String recordingProfile;

  /// EPG timezone for display.
  ///
  /// Values: 'system' (device timezone), 'UTC', or IANA identifier
  /// (e.g., 'America/New_York', 'Europe/London').
  final String epgTimezone;

  /// Audio output driver for playback.
  ///
  /// Values: 'auto', 'spdif', 'hdmi', 'pulse', 'alsa', 'wasapi', 'coreaudio'.
  /// See [AudioOutput] enum for all valid values.
  final String audioOutput;

  /// Enable audio passthrough for surround sound codecs.
  ///
  /// When enabled, audio bitstream is sent directly to AV receiver
  /// without decoding (for Dolby Digital, DTS, etc.).
  final bool audioPassthroughEnabled;

  /// List of audio codecs to passthrough when [audioPassthroughEnabled] is true.
  ///
  /// Valid values: 'ac3', 'eac3', 'truehd', 'dts', 'dts-hd'.
  /// See [PassthroughCodec] enum for all valid values.
  final List<String> audioPassthroughCodecs;

  /// External player preference.
  ///
  /// Values: 'none' (use built-in), 'systemDefault', 'vlc',
  /// 'mxPlayer', 'mxPlayerPro', 'kodi', 'justPlayer', 'mpv'.
  /// See [ExternalPlayer] enum for all valid values.
  final String externalPlayer;

  /// Pause playback when desktop window loses focus.
  ///
  /// When enabled, playback auto-pauses on alt-tab or clicking
  /// another window, and auto-resumes when the window regains
  /// focus. Desktop only (Windows/Linux/macOS).
  final bool pauseOnFocusLoss;

  /// Global upscaling master switch (Experimental).
  ///
  /// When `false` (default), the entire upscaling
  /// pipeline is bypassed — standard bilinear playback.
  /// Not per-profile; applies to all users.
  final bool upscaleEnabled;

  /// Video upscaling mode: 'auto', 'off',
  /// 'forceHardware', 'forceSoftware'.
  final String upscaleMode;

  /// Video upscaling quality preset: 'performance',
  /// 'balanced', 'maximum'.
  final String upscaleQuality;

  /// Seek step in seconds for skip-back / skip-forward.
  ///
  /// Valid values: 5, 10, 15, 20, 30.
  final int seekStepSeconds;

  /// Deinterlace mode for live TV playback.
  ///
  /// Values: 'off' (disabled), 'auto' (media_kit auto-detect).
  /// Actual media_kit property apply is deferred (TODO).
  final String deinterlaceMode;

  /// Whether to show Skip Intro / Skip Credits buttons
  /// during VOD playback (FE-PS-03).
  ///
  /// When `true` (default), the floating pill button
  /// appears whenever playback enters a [SkipSegment]
  /// range. Set to `false` to suppress the button.
  final bool showSkipButtons;

  /// EBU R128 loudness normalization for consistent volume across channels.
  ///
  /// When enabled, applies `loudnorm=I=-14:TP=-1:LRA=13` mpv audio filter.
  final bool loudnessNormalization;

  /// Force surround audio to stereo downmix.
  ///
  /// When enabled, sets mpv `audio-channels=stereo` for headphone users.
  final bool stereoDownmix;

  /// Per-type segment skip configuration as JSON string.
  ///
  /// Maps [SegmentType] name to [SegmentSkipMode] name.
  /// Empty string = use defaults (all types = ask).
  /// See [decodeSegmentSkipConfig] / [encodeSegmentSkipConfig].
  final String segmentSkipConfig;

  /// Next-up overlay trigger mode.
  ///
  /// Values: 'off', 'static' (32s before end), 'smart' (credits-aware).
  /// Default: 'static'.
  final String nextUpMode;

  /// Maximum volume percentage (100–300).
  ///
  /// At 100 (default), volume slider caps at 100%.
  /// Higher values enable volume boost (e.g. 200 = 200%).
  /// Sets mpv `volume-max` property.
  final int maxVolume;

  /// Whether external player is configured (not 'none').
  bool get useExternalPlayer => externalPlayer != 'none';

  Map<String, dynamic> toJson() => _$PlayerConfigToJson(this);
}

@JsonSerializable()
class ThemeConfig {
  const ThemeConfig({
    required this.mode,
    required this.seedColorHex,
    required this.useDynamicColor,
  });

  factory ThemeConfig.fromJson(Map<String, dynamic> json) =>
      _$ThemeConfigFromJson(json);

  /// One of: "light", "dark", "system".
  final String mode;

  /// Hex color string used as Material 3 seed.
  final String seedColorHex;

  /// Whether to use platform dynamic color (Android 12+).
  final bool useDynamicColor;

  Map<String, dynamic> toJson() => _$ThemeConfigToJson(this);
}

@JsonSerializable()
class FeaturesConfig {
  const FeaturesConfig({
    required this.iptvEnabled,
    required this.jellyfinEnabled,
    required this.plexEnabled,
    required this.embyEnabled,
  });

  factory FeaturesConfig.fromJson(Map<String, dynamic> json) =>
      _$FeaturesConfigFromJson(json);

  final bool iptvEnabled;
  final bool jellyfinEnabled;
  final bool plexEnabled;
  final bool embyEnabled;

  Map<String, dynamic> toJson() => _$FeaturesConfigToJson(this);
}

@JsonSerializable()
class CacheConfig {
  const CacheConfig({
    required this.epgRefreshIntervalMinutes,
    required this.channelListRefreshIntervalMinutes,
    required this.maxCachedEpgDays,
    this.maxImageCacheMb = 50,
    this.maxImageMemCacheObjects = 50,
    this.maxImageDiskCacheObjects = 2000,
    this.imageDiskCacheRetentionDays = 30,
  });

  factory CacheConfig.fromJson(Map<String, dynamic> json) =>
      _$CacheConfigFromJson(json);

  final int epgRefreshIntervalMinutes;
  final int channelListRefreshIntervalMinutes;
  final int maxCachedEpgDays;
  final int maxImageCacheMb;
  final int maxImageMemCacheObjects;
  final int maxImageDiskCacheObjects;
  final int imageDiskCacheRetentionDays;

  Map<String, dynamic> toJson() => _$CacheConfigToJson(this);
}
