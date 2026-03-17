using Android.App;
using Android.Content;
using Android.Content.PM;

using Avalonia;
using Avalonia.Android;

using Crispy.Application;
using Crispy.Application.Player;
using Crispy.Android.Services;
using Crispy.Infrastructure;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Data.Seed;
using Crispy.UI;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
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
        // ── VLC initialization ─────────────────────────────────────────────────
        try
        {
            LibVLCSharp.Shared.Core.Initialize();
            // Console.WriteLine("[DIAG]VLC Core.Initialize succeeded");
        }
        catch (Exception ex)
        {
            global::Android.Util.Log.Warn("CrispyTivi", $"VLC Core.Initialize failed — playback disabled: {ex.Message}");
        }

        // ── DI container (mirrors Desktop/Program.cs) ──────────────────────────
        try
        {
            var dataDir = System.IO.Path.Combine(
                System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData),
                "CrispyTivi");
            System.IO.Directory.CreateDirectory(dataDir);

            var connectionString = $"Data Source={System.IO.Path.Combine(dataDir, "crispy.db")}";

            // Build a minimal in-memory configuration (no appsettings.json on Android)
            var configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["ConnectionStrings:DefaultConnection"] = connectionString,
                    ["Paths:Data"] = dataDir,
                })
                .Build();

            var services = new ServiceCollection();
            services.AddSingleton<IConfiguration>(configuration);
            services.AddApplicationServices();
            services.AddInfrastructureServices(configuration, connectionString);
            services.AddUiServices();

            // Android-specific overrides
            ConfigureAndroidServices(services, this);

            var provider = services.BuildServiceProvider();

            // Ensure database exists
            var dbFactory = provider.GetRequiredService<IDbContextFactory<AppDbContext>>();
            using (var context = dbFactory.CreateDbContext())
            {
                context.Database.EnsureCreated();
            }

            DatabaseSeeder.SeedAsync(dbFactory).GetAwaiter().GetResult();

            App.Services = provider;
            // Console.WriteLine("[DIAG]DI container built and App.Services set");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[DIAG] DI setup FAILED: {ex}");
            global::Android.Util.Log.Error("CrispyTivi", $"DI setup failed: {ex}");
        }

        return base.CustomizeAppBuilder(builder)
            .WithInterFont();
    }

    /// <summary>
    /// Configures Android-specific DI overrides:
    /// - AndroidMediaSessionBridge replaces NullMediaSessionService
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
