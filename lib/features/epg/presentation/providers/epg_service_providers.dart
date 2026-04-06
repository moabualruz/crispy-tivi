// Re-exports of data-layer providers for use in the
// epg presentation layer. Widgets must import from
// here, never directly from data/.
export '../../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider, crispyBackendProvider;
export '../../../dvr/data/dvr_service.dart'
    show DvrService, DvrState, dvrServiceProvider;
export '../../../dvr/data/dvr_state.dart' show ScheduleResult;
export '../../../iptv/data/services/catchup_url_builder.dart'
    show CatchupUrlBuilder;
export '../../../notifications/data/notification_service.dart'
    show NotificationService, NotificationState, notificationServiceProvider,
        ToastType, AppToast, ProgramReminder;
export '../../../player/data/external_player_service.dart'
    show ExternalPlayer, ExternalPlayerService, externalPlayerServiceProvider;
