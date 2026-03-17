using Foundation;

using Avalonia;
using Avalonia.iOS;

using Crispy.Application;
using Crispy.Infrastructure;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Data.Seed;
using Crispy.UI;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Crispy.iOS;

[Register("AppDelegate")]
#pragma warning disable CA1711 // Identifiers should not have incorrect suffix
public partial class AppDelegate : AvaloniaAppDelegate<App>
#pragma warning restore CA1711 // Identifiers should not have incorrect suffix
{
    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        // ── DI container (mirrors Desktop/Program.cs) ──────────────────────────
        try
        {
            var dataDir = System.IO.Path.Combine(
                System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData),
                "CrispyTivi");
            System.IO.Directory.CreateDirectory(dataDir);

            var connectionString = $"Data Source={System.IO.Path.Combine(dataDir, "crispy.db")}";

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

            var provider = services.BuildServiceProvider();

            // Ensure database exists
            var dbFactory = provider.GetRequiredService<IDbContextFactory<AppDbContext>>();
            using (var context = dbFactory.CreateDbContext())
            {
                context.Database.EnsureCreated();
            }

            DatabaseSeeder.SeedAsync(dbFactory).GetAwaiter().GetResult();

            App.Services = provider;
            Console.WriteLine("[DIAG] iOS DI container built and App.Services set");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[DIAG] iOS DI setup FAILED: {ex}");
        }

        return base.CustomizeAppBuilder(builder)
            .WithInterFont();
    }
}
