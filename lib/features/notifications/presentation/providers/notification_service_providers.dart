/// Re-exports for notifications presentation layer.
///
/// Widgets in [notifications/presentation/widgets/] must import from this file
/// instead of reaching directly into data/ layers (DIP / ISP compliance).
export '../../data/notification_service.dart'
    show
        NotificationService,
        NotificationState,
        AppToast,
        ProgramReminder,
        notificationServiceProvider;
