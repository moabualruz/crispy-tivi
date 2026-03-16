using Android.App;
using Android.Content;
using Android.Content.PM;

using Avalonia;
using Avalonia.Android;

using Crispy.Application.Player;
using Crispy.Android.Services;
using Crispy.Infrastructure;
using Crispy.UI;

using Microsoft.Extensions.DependencyInjection;

namespace Crispy.Android;

[Activity(
    Label = "CrispyTivi",
    Theme = "@style/MyTheme.NoActionBar",
    Icon = "@drawable/icon",
    MainLauncher = true,
    ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.UiMode)]
public class MainActivity : AvaloniaMainActivity<App>
{
    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        // Core.Initialize() must be called BEFORE any LibVLC usage (before DI resolves VlcPlayerService).
        // Called here at the earliest safe point — before base.OnCreate() has run.
        try
        {
            LibVLCSharp.Shared.Core.Initialize();
        }
        catch (Exception ex)
        {
            Android.Util.Log.Warn("CrispyTivi", $"VLC Core.Initialize failed — playback disabled: {ex.Message}");
        }

        return base.CustomizeAppBuilder(builder)
            .WithInterFont();
    }

    /// <summary>
    /// Configures Android-specific DI overrides:
    /// - AndroidMediaSessionBridge replaces NullMediaSessionService
    /// - Starts CrispyMediaService foreground service
    /// </summary>
    private static IServiceCollection ConfigureAndroidServices(IServiceCollection services, Context context)
    {
        // Override media session service with Android bridge
        services.AddSingleton<IMediaSessionService>(sp =>
            new AndroidMediaSessionBridge(
                context,
                sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<AndroidMediaSessionBridge>>(),
                sp.GetRequiredService<System.Net.Http.IHttpClientFactory>()
                    .CreateClient("ArtworkLoader")));

        return services;
    }
}
