// Re-exports for widget consumption — keeps widgets decoupled from data layer.
// Widgets import this file instead of importing data/ directly.
export '../../../../core/data/screenshot_service.dart'
    show ScreenshotService, screenshotServiceProvider;
export '../../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, crispyBackendProvider;
export '../../data/afr_service.dart' show AfrService, afrServiceProvider;
export '../../data/player_service.dart' show PlayerService;
export '../../data/shader_service.dart'
    show ShaderPreset, ShaderService, shaderPresetProvider;
export '../../data/watch_history_service.dart'
    show WatchHistoryService, watchHistoryServiceProvider;
export '../../data/web_video_bridge_web.dart' show escapeJs;
export '../../data/segment_skip_codec.dart'
    show decodeSegmentSkipConfig, encodeSegmentSkipConfig;
export '../../data/thumbnail_service.dart'
    show ThumbnailService, ThumbnailSource, ThumbnailRegion;
export '../../data/gpu_json_codec.dart' show GpuJsonCodec;
export '../../data/upscale_manager.dart' show UpscaleManager;
