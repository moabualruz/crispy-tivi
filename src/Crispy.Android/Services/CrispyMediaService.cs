using Android.App;
using Android.Content;
using Android.Media;
using Android.OS;

namespace Crispy.Android.Services;

/// <summary>
/// Android foreground MediaSessionService that keeps playback alive when the
/// app is backgrounded. Displays a media-style notification with play/pause
/// controls and channel artwork.
///
/// Declared in AndroidManifest.xml with:
///   android:foregroundServiceType="mediaPlayback"
///   uses-permission: FOREGROUND_SERVICE + FOREGROUND_SERVICE_MEDIA_PLAYBACK
/// </summary>
[Service(
    Exported = false,
    ForegroundServiceType = global::Android.Content.PM.ForegroundService.TypeMediaPlayback)]
public sealed class CrispyMediaService : Service
{
    private const int NotificationId = 1001;
    private const string ChannelId = "crispy_playback";
    private const string ChannelName = "Playback";

    private IBinder? _binder;

    /// <inheritdoc />
    public override void OnCreate()
    {
        base.OnCreate();
        CreateNotificationChannel();
        StartForeground(NotificationId, BuildMediaNotification(title: "CrispyTivi", channelName: null));
    }

    /// <inheritdoc />
    public override IBinder? OnBind(Intent? intent)
    {
        _binder ??= new CrispyMediaBinder(this);
        return _binder;
    }

    /// <inheritdoc />
    public override StartCommandResult OnStartCommand(Intent? intent, StartCommandFlags flags, int startId)
    {
        return StartCommandResult.Sticky;
    }

    /// <inheritdoc />
    public override void OnDestroy()
    {
        StopForeground(StopForegroundFlags.Remove);
        base.OnDestroy();
    }

    /// <summary>
    /// Updates the notification with new metadata (called by AndroidMediaSessionBridge).
    /// </summary>
    public void UpdateNotification(string title, string? channelName)
    {
        var notification = BuildMediaNotification(title, channelName);
        var manager = (NotificationManager?)GetSystemService(NotificationService);
        manager?.Notify(NotificationId, notification);
    }

    private Notification BuildMediaNotification(string title, string? channelName)
    {
        var builder = new Notification.Builder(this, ChannelId)
            .SetContentTitle(title)
            .SetContentText(channelName ?? string.Empty)
            .SetSmallIcon(global::Android.Resource.Drawable.IcMediaPlay)
            .SetOngoing(true)
            .SetVisibility(NotificationVisibility.Public);

        // Media-style notification for lock-screen and notification shade
        builder.SetStyle(new Notification.MediaStyle());

        return builder.Build()!;
    }

    private void CreateNotificationChannel()
    {
        var channel = new NotificationChannel(
            ChannelId,
            ChannelName,
            NotificationImportance.Low)
        {
            Description = "CrispyTivi media playback",
        };

        var manager = (NotificationManager?)GetSystemService(NotificationService);
        manager?.CreateNotificationChannel(channel);
    }

    /// <summary>Binder that exposes the service instance to MainActivity.</summary>
    public sealed class CrispyMediaBinder : Binder
    {
        public CrispyMediaService Service { get; }

        public CrispyMediaBinder(CrispyMediaService service)
        {
            Service = service;
        }
    }
}
