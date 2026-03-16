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

        // Override the connection string with an absolute path so the DB file
        // is always written to the same location regardless of working directory.
        var rawConnection = configuration.GetConnectionString("DefaultConnection")
            ?? "Data Source=crispy.db";
        var absoluteConnection = MakeAbsoluteDbPath(rawConnection);

        var services = new ServiceCollection();
        services.AddSingleton<IConfiguration>(configuration);
        services.AddApplicationServices();
        services.AddInfrastructureServices(configuration, absoluteConnection);
        services.AddUiServices();

        Services = services.BuildServiceProvider();

        // Ensure database schema matches the current model.
        // EnsureCreated() creates all tables from the model on first run but cannot
        // add columns to existing tables. When the schema evolves, we detect stale
        // DBs and recreate them. This is safe during early development; production
        // will switch to Migrate() once an initial migration baseline is created.
        var dbFactory = Services.GetRequiredService<IDbContextFactory<AppDbContext>>();
        using (var context = dbFactory.CreateDbContext())
        {
            if (context.Database.CanConnect())
            {
                // Detect schema drift: if a column added in a later phase is missing,
                // the DB was created before that column existed. Recreate it.
                var conn = context.Database.GetDbConnection();
                conn.Open();
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "SELECT count(*) FROM pragma_table_info('Sources') WHERE name='EncryptedPassword'";
                var hasEncryptedCol = Convert.ToInt64(cmd.ExecuteScalar()) > 0;
                conn.Close();

                if (!hasEncryptedCol)
                {
                    Console.WriteLine("[DB] Stale schema detected (missing EncryptedPassword). Recreating DB...");
                    context.Database.EnsureDeleted();
                }
            }

            context.Database.EnsureCreated();
        }

        DatabaseSeeder.SeedAsync(dbFactory).GetAwaiter().GetResult();

        App.Services = Services;

        // GStreamer initialization is handled lazily by GstreamerPlayerService at construction time
        // via runtime detection (IsGstreamerAvailable). No pre-init call needed here.

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

    // Rewrites a SQLite connection string so the Data Source is an absolute
    // path anchored to AppContext.BaseDirectory.  If the source is already
    // absolute it is returned unchanged.
    private static string MakeAbsoluteDbPath(string connectionString)
    {
        const string prefix1 = "Data Source=";
        const string prefix2 = "DataSource=";

        string? ExtractSource(string cs, string key)
        {
            var idx = cs.IndexOf(key, StringComparison.OrdinalIgnoreCase);
            if (idx < 0)
            {
                return null;
            }

            var start = idx + key.Length;
            var end = cs.IndexOf(';', start);
            return end < 0 ? cs[start..] : cs[start..end];
        }

        var source = ExtractSource(connectionString, prefix1)
            ?? ExtractSource(connectionString, prefix2);

        if (source is null || Path.IsPathRooted(source))
        {
            Console.WriteLine($"[DB] Using DB path as-is: {source ?? connectionString}");
            return connectionString;
        }

        var absoluteSource = Path.Combine(AppContext.BaseDirectory, source);
        Console.WriteLine($"[DB] Resolved DB path: {absoluteSource}");
        return connectionString.Replace(source, absoluteSource, StringComparison.Ordinal);
    }
}
