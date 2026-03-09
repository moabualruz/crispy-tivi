// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
  appName: json['appName'] as String,
  appVersion: json['appVersion'] as String,
  api: ApiConfig.fromJson(json['api'] as Map<String, dynamic>),
  player: PlayerConfig.fromJson(json['player'] as Map<String, dynamic>),
  theme: ThemeConfig.fromJson(json['theme'] as Map<String, dynamic>),
  features: FeaturesConfig.fromJson(json['features'] as Map<String, dynamic>),
  cache: CacheConfig.fromJson(json['cache'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
  'appName': instance.appName,
  'appVersion': instance.appVersion,
  'api': instance.api.toJson(),
  'player': instance.player.toJson(),
  'theme': instance.theme.toJson(),
  'features': instance.features.toJson(),
  'cache': instance.cache.toJson(),
};

ApiConfig _$ApiConfigFromJson(Map<String, dynamic> json) => ApiConfig(
  baseUrl: json['baseUrl'] as String,
  backendPort: (json['backendPort'] as num).toInt(),
  connectTimeoutMs: (json['connectTimeoutMs'] as num).toInt(),
  receiveTimeoutMs: (json['receiveTimeoutMs'] as num).toInt(),
  sendTimeoutMs: (json['sendTimeoutMs'] as num).toInt(),
);

Map<String, dynamic> _$ApiConfigToJson(ApiConfig instance) => <String, dynamic>{
  'baseUrl': instance.baseUrl,
  'backendPort': instance.backendPort,
  'connectTimeoutMs': instance.connectTimeoutMs,
  'receiveTimeoutMs': instance.receiveTimeoutMs,
  'sendTimeoutMs': instance.sendTimeoutMs,
};

PlayerConfig _$PlayerConfigFromJson(Map<String, dynamic> json) => PlayerConfig(
  defaultBufferDurationMs: (json['defaultBufferDurationMs'] as num).toInt(),
  autoPlay: json['autoPlay'] as bool,
  defaultAspectRatio: json['defaultAspectRatio'] as String,
  hwdecMode: json['hwdecMode'] as String? ?? 'auto',
  afrEnabled: json['afrEnabled'] as bool? ?? false,
  afrLiveTv: json['afrLiveTv'] as bool? ?? true,
  afrVod: json['afrVod'] as bool? ?? true,
  pipOnMinimize: json['pipOnMinimize'] as bool? ?? true,
  streamProfile: json['streamProfile'] as String? ?? 'auto',
  recordingProfile: json['recordingProfile'] as String? ?? 'original',
  epgTimezone: json['epgTimezone'] as String? ?? 'system',
  audioOutput: json['audioOutput'] as String? ?? 'auto',
  audioPassthroughEnabled: json['audioPassthroughEnabled'] as bool? ?? false,
  audioPassthroughCodecs:
      (json['audioPassthroughCodecs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const ['ac3', 'dts'],
  externalPlayer: json['externalPlayer'] as String? ?? 'none',
  pauseOnFocusLoss: json['pauseOnFocusLoss'] as bool? ?? false,
  upscaleEnabled: json['upscaleEnabled'] as bool? ?? false,
  upscaleMode: json['upscaleMode'] as String? ?? 'auto',
  upscaleQuality: json['upscaleQuality'] as String? ?? 'balanced',
  seekStepSeconds: (json['seekStepSeconds'] as num?)?.toInt() ?? 10,
  deinterlaceMode: json['deinterlaceMode'] as String? ?? 'off',
  showSkipButtons: json['showSkipButtons'] as bool? ?? true,
  loudnessNormalization: json['loudnessNormalization'] as bool? ?? true,
  stereoDownmix: json['stereoDownmix'] as bool? ?? false,
  segmentSkipConfig: json['segmentSkipConfig'] as String? ?? '',
  nextUpMode: json['nextUpMode'] as String? ?? 'static',
  maxVolume: (json['maxVolume'] as num?)?.toInt() ?? 100,
);

Map<String, dynamic> _$PlayerConfigToJson(PlayerConfig instance) =>
    <String, dynamic>{
      'defaultBufferDurationMs': instance.defaultBufferDurationMs,
      'autoPlay': instance.autoPlay,
      'defaultAspectRatio': instance.defaultAspectRatio,
      'hwdecMode': instance.hwdecMode,
      'afrEnabled': instance.afrEnabled,
      'afrLiveTv': instance.afrLiveTv,
      'afrVod': instance.afrVod,
      'pipOnMinimize': instance.pipOnMinimize,
      'streamProfile': instance.streamProfile,
      'recordingProfile': instance.recordingProfile,
      'epgTimezone': instance.epgTimezone,
      'audioOutput': instance.audioOutput,
      'audioPassthroughEnabled': instance.audioPassthroughEnabled,
      'audioPassthroughCodecs': instance.audioPassthroughCodecs,
      'externalPlayer': instance.externalPlayer,
      'pauseOnFocusLoss': instance.pauseOnFocusLoss,
      'upscaleEnabled': instance.upscaleEnabled,
      'upscaleMode': instance.upscaleMode,
      'upscaleQuality': instance.upscaleQuality,
      'seekStepSeconds': instance.seekStepSeconds,
      'deinterlaceMode': instance.deinterlaceMode,
      'showSkipButtons': instance.showSkipButtons,
      'loudnessNormalization': instance.loudnessNormalization,
      'stereoDownmix': instance.stereoDownmix,
      'segmentSkipConfig': instance.segmentSkipConfig,
      'nextUpMode': instance.nextUpMode,
      'maxVolume': instance.maxVolume,
    };

ThemeConfig _$ThemeConfigFromJson(Map<String, dynamic> json) => ThemeConfig(
  mode: json['mode'] as String,
  seedColorHex: json['seedColorHex'] as String,
  useDynamicColor: json['useDynamicColor'] as bool,
);

Map<String, dynamic> _$ThemeConfigToJson(ThemeConfig instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'seedColorHex': instance.seedColorHex,
      'useDynamicColor': instance.useDynamicColor,
    };

FeaturesConfig _$FeaturesConfigFromJson(Map<String, dynamic> json) =>
    FeaturesConfig(
      iptvEnabled: json['iptvEnabled'] as bool,
      jellyfinEnabled: json['jellyfinEnabled'] as bool,
      plexEnabled: json['plexEnabled'] as bool,
      embyEnabled: json['embyEnabled'] as bool,
    );

Map<String, dynamic> _$FeaturesConfigToJson(FeaturesConfig instance) =>
    <String, dynamic>{
      'iptvEnabled': instance.iptvEnabled,
      'jellyfinEnabled': instance.jellyfinEnabled,
      'plexEnabled': instance.plexEnabled,
      'embyEnabled': instance.embyEnabled,
    };

CacheConfig _$CacheConfigFromJson(Map<String, dynamic> json) => CacheConfig(
  epgRefreshIntervalMinutes: (json['epgRefreshIntervalMinutes'] as num).toInt(),
  channelListRefreshIntervalMinutes:
      (json['channelListRefreshIntervalMinutes'] as num).toInt(),
  maxCachedEpgDays: (json['maxCachedEpgDays'] as num).toInt(),
  maxImageCacheMb: (json['maxImageCacheMb'] as num?)?.toInt() ?? 50,
  maxImageMemCacheObjects:
      (json['maxImageMemCacheObjects'] as num?)?.toInt() ?? 50,
  maxImageDiskCacheObjects:
      (json['maxImageDiskCacheObjects'] as num?)?.toInt() ?? 2000,
  imageDiskCacheRetentionDays:
      (json['imageDiskCacheRetentionDays'] as num?)?.toInt() ?? 30,
);

Map<String, dynamic> _$CacheConfigToJson(CacheConfig instance) =>
    <String, dynamic>{
      'epgRefreshIntervalMinutes': instance.epgRefreshIntervalMinutes,
      'channelListRefreshIntervalMinutes':
          instance.channelListRefreshIntervalMinutes,
      'maxCachedEpgDays': instance.maxCachedEpgDays,
      'maxImageCacheMb': instance.maxImageCacheMb,
      'maxImageMemCacheObjects': instance.maxImageMemCacheObjects,
      'maxImageDiskCacheObjects': instance.maxImageDiskCacheObjects,
      'imageDiskCacheRetentionDays': instance.imageDiskCacheRetentionDays,
    };
