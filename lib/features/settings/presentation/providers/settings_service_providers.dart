// Re-exports of data-layer providers for use in the
// settings presentation layer. Widgets must import from
// here, never directly from data/.
export '../../../../core/data/app_directories.dart';
export '../../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, crispyBackendProvider;
export '../../../../core/data/codecs/json_prefs_codec.dart';
export '../../../../core/data/dart_algorithm_fallbacks.dart';
export '../../../../core/data/device_service.dart'
    show DeviceService, DeviceInfo, deviceServiceProvider;
export '../../data/backup_service.dart'
    show BackupService, BackupSummary, backupServiceProvider;
export '../../data/network_diagnostics_service.dart'
    show DiagStatus, DiagResult, NetworkDiagnosticsService;
export '../../data/stalker_account_info.dart'
    show StalkerAccountInfo, fetchStalkerAccountInfoFromRef;
export '../../data/web_sync_service.dart'
    show webSyncServiceProvider;
export '../../../player/data/segment_skip_codec.dart';
