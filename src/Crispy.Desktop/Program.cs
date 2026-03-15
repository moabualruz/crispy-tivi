using Avalonia;

using Crispy.Application;
using Crispy.Infrastructure;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Data.Seed;
using Crispy.UI;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Crispy.Desktop;

/// <summary>
/// Desktop application entry point.
/// </summary>
internal sealed class Program
{
    /// <summary>
    /// Service provider for the application.
    /// </summary>
    internal static ServiceProvider? Services { get; private set; }

    [STAThread]
    public static void Main(string[] args)
    {
        var configuration = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
            .Build();

        var services = new ServiceCollection();
        services.AddSingleton<IConfiguration>(configuration);
        services.AddApplicationServices();
        services.AddInfrastructureServices(configuration);
        services.AddUiServices();

        Services = services.BuildServiceProvider();

        // Ensure database is created and seeded
        var dbFactory = Services.GetRequiredService<IDbContextFactory<AppDbContext>>();
        using (var context = dbFactory.CreateDbContext())
        {
            context.Database.EnsureCreated();
        }

        DatabaseSeeder.SeedAsync(dbFactory).GetAwaiter().GetResult();

        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }

    /// <summary>
    /// Avalonia configuration, also used by the visual designer.
    /// </summary>
    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();
}
