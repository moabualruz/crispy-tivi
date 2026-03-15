using System.Runtime.Versioning;
using System.Threading.Tasks;

using Avalonia;
using Avalonia.Browser;

using Crispy.Application;
using Crispy.Application.Player;
using Crispy.Browser.Player;
using Crispy.UI;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

[assembly: SupportedOSPlatform("browser")]

namespace Crispy.Browser;

/// <summary>
/// Browser/WASM application entry point.
/// Configures a minimal DI container for the browser target — no Infrastructure
/// project reference (EF Core / SQLite are not available in WASM).
/// IPlayerService is provided by HtmlVideoPlayerService (HTML5 video via JS interop).
/// </summary>
internal sealed partial class Program
{
    private static Task Main(string[] args)
    {
        var services = new ServiceCollection();

        services.AddApplicationServices();
        services.AddUiServices();
        services.AddLogging(b => b.AddConsole());

        // Browser player — HTML5 video via JS interop (no VLC)
        services.AddSingleton<IPlayerService, HtmlVideoPlayerService>();

        // Null implementations for services unavailable in browser
        services.AddSingleton<ITimeshiftService, Crispy.Application.Player.NullTimeshiftService>();
        services.AddSingleton<IAudioStreamDetector, Crispy.Application.Player.NullAudioStreamDetector>();
        services.AddSingleton<IMediaSessionService, Crispy.Application.Player.NullMediaSessionService>();

        App.Services = services.BuildServiceProvider();

        return BuildAvaloniaApp()
            .WithInterFont()
            .StartBrowserAppAsync("out");
    }

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>();
}
