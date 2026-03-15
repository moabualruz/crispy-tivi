using Crispy.Application.Configuration;
using Crispy.Domain.Interfaces;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Logging;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

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
        // EF Core with SQLite — prefer the override (absolute path) if supplied
        var connectionString = connectionStringOverride
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? "Data Source=crispy.db";

        services.AddDbContextFactory<AppDbContext>(options =>
            options.UseSqlite(connectionString));

        // Repositories
        services.AddScoped<ISettingsRepository, SettingsRepository>();
        services.AddScoped<ISourceRepository, SourceRepository>();
        services.AddScoped<IProfileRepository, ProfileRepository>();

        // Feature flags
        services.Configure<FeatureFlagOptions>(
            configuration.GetSection(FeatureFlagOptions.Section));

        // Caching
        services.AddMemoryCache();

        // HTTP client factory
        services.AddHttpClient();

        // Logging
        services.AddLogging(builder => builder.AddSerilogLogging());

        return services;
    }
}
