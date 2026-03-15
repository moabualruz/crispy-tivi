using System.IO;

using Crispy.Application.Configuration;
using Crispy.Application.Sources;
using Crispy.Application.Sync;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using Crispy.Infrastructure.Connectivity;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Jellyfin;
using Crispy.Infrastructure.Logging;
using Crispy.Infrastructure.Parsers.M3U;
using Crispy.Infrastructure.Parsers.Stalker;
using Crispy.Infrastructure.Parsers.Xmltv;
using Crispy.Infrastructure.Parsers.Xtream;
using Crispy.Infrastructure.Security;
using Crispy.Infrastructure.Sync;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure;

/// <summary>
/// Registers infrastructure layer services.
/// </summary>
public static class DependencyInjection
{
    /// <summary>
    /// Adds infrastructure services to the DI container.
    /// </summary>
    /// <param name="services">The service collection to configure.</param>
    /// <param name="configuration">Application configuration.</param>
    /// <param name="connectionStringOverride">
    /// Optional fully-resolved connection string. When provided this takes
    /// precedence over the value in <paramref name="configuration"/>.
    /// </param>
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration,
        string? connectionStringOverride = null)
    {
        // Resolve the data directory from config or use a sensible default
        var dataDir = configuration["Paths:Data"]
            ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "CrispyTivi");

        Directory.CreateDirectory(dataDir);

        // EF Core — main database (prefer the override absolute path if supplied)
        var connectionString = connectionStringOverride
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? $"Data Source={Path.Combine(dataDir, "crispy.db")}";

        services.AddDbContextFactory<AppDbContext>(options =>
            options.UseSqlite(connectionString));

        // EF Core — EPG database (separate file for high-write EPG data)
        var epgConnectionString = $"Data Source={Path.Combine(dataDir, "epg.db")}";
        services.AddDbContextFactory<EpgDbContext>(options =>
            options.UseSqlite(epgConnectionString));

        // ─── Repositories ─────────────────────────────────────────────────────
        services.AddScoped<ISettingsRepository, SettingsRepository>();
        services.AddScoped<ISourceRepository, SourceRepository>();
        services.AddScoped<IProfileRepository, ProfileRepository>();
        services.AddScoped<IChannelRepository, ChannelRepository>();
        services.AddScoped<IEpgRepository, EpgRepository>();
        services.AddScoped<ISyncHistoryRepository, SyncHistoryRepository>();

        // ─── Security ─────────────────────────────────────────────────────────
        services.AddSingleton<ICredentialEncryption, CredentialEncryption>();

        // ─── Feature flags ────────────────────────────────────────────────────
        services.Configure<FeatureFlagOptions>(
            configuration.GetSection(FeatureFlagOptions.Section));

        // ─── Caching ──────────────────────────────────────────────────────────
        services.AddMemoryCache();

        // ─── HTTP clients ─────────────────────────────────────────────────────
        services.AddHttpClient();

        // Named HTTP client for Xtream Codes (Polly resilience inline — no extension method needed)
        services.AddHttpClient("XtreamClient");

        // Named HTTP client for Stalker Portal
        services.AddHttpClient("StalkerClient");

        // HTTP client for connectivity probing
        services.AddHttpClient("ConnectivityProbe");

        // ─── Parsers ──────────────────────────────────────────────────────────
        services.AddTransient<M3UParser>();
        services.AddTransient<XmltvParser>();

        // Xtream parser: typed client resolved from IHttpClientFactory
        services.AddTransient<XtreamClient>(sp =>
        {
            var factory = sp.GetRequiredService<IHttpClientFactory>();
            return new XtreamClient(factory.CreateClient("XtreamClient"));
        });
        services.AddTransient<XtreamParser>();

        // Stalker parser: typed client resolved from IHttpClientFactory
        services.AddTransient<StalkerClient>(sp =>
        {
            var factory = sp.GetRequiredService<IHttpClientFactory>();
            return new StalkerClient(factory.CreateClient("StalkerClient"), mac: null);
        });
        services.AddTransient<StalkerParser>();

        // ─── Jellyfin ─────────────────────────────────────────────────────────
        services.AddSingleton<JellyfinDiscovery>();
        services.AddHttpClient("JellyfinDiscovery");

        // Jellyfin client factory — one JellyfinClient instance per Source
        services.AddTransient<Func<Source, JellyfinClient>>(sp => source =>
        {
            var factory = sp.GetRequiredService<IHttpClientFactory>();
            var httpClient = factory.CreateClient("JellyfinClient");
            httpClient.BaseAddress = new Uri(source.Url.TrimEnd('/') + "/");
            return new JellyfinClient(
                source.Url,
                accessToken: null,
                sp.GetRequiredService<ICredentialEncryption>(),
                httpClient,
                sp.GetRequiredService<ILogger<JellyfinClient>>());
        });
        services.AddHttpClient("JellyfinClient");
        services.AddTransient<JellyfinSyncService>();

        // ─── Parser registry (keyed by SourceType) ────────────────────────────
        services.AddSingleton<IReadOnlyDictionary<SourceType, ISourceParser>>(sp =>
        {
            // Build a snapshot at startup; transient parsers are resolved once here
            var dict = new Dictionary<SourceType, ISourceParser>
            {
                [SourceType.M3U] = ActivatorUtilities.CreateInstance<XtreamParser>(sp,
                    sp.GetRequiredService<XtreamClient>(),
                    sp.GetRequiredService<M3UParser>(),
                    sp.GetRequiredService<ILogger<XtreamParser>>()),
                [SourceType.XtreamCodes] = ActivatorUtilities.CreateInstance<XtreamParser>(sp,
                    sp.GetRequiredService<XtreamClient>(),
                    sp.GetRequiredService<M3UParser>(),
                    sp.GetRequiredService<ILogger<XtreamParser>>()),
                [SourceType.StalkerPortal] = ActivatorUtilities.CreateInstance<StalkerParser>(sp,
                    sp.GetRequiredService<StalkerClient>(),
                    sp.GetRequiredService<ILogger<StalkerParser>>()),
                [SourceType.Jellyfin] = sp.GetRequiredService<JellyfinSyncService>(),
            };
            return dict;
        });

        // ─── Sync engine ──────────────────────────────────────────────────────
        services.AddTransient<SyncPipeline>();
        services.AddTransient<ChannelDeduplicator>();

        services.AddSingleton<SyncScheduler>(sp => new SyncScheduler(
            syncAllCallback: ct => sp.GetRequiredService<SyncOrchestrator>().SyncAllAsync(ct),
            logger: sp.GetRequiredService<ILogger<SyncScheduler>>()));

        services.AddSingleton<SyncOrchestrator>();
        services.AddSingleton<ISyncOrchestrator>(sp => sp.GetRequiredService<SyncOrchestrator>());
        services.AddSingleton<IHostedService>(sp => sp.GetRequiredService<SyncOrchestrator>());

        // ─── Connectivity ─────────────────────────────────────────────────────
        services.AddSingleton<IConnectivityMonitor>(sp =>
        {
            var factory = sp.GetRequiredService<IHttpClientFactory>();
            return new ConnectivityMonitor(
                factory.CreateClient("ConnectivityProbe"),
                sp.GetRequiredService<ILogger<ConnectivityMonitor>>());
        });

        // ─── Logging ──────────────────────────────────────────────────────────
        services.AddLogging(builder => builder.AddSerilogLogging());

        return services;
    }
}
