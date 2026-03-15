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
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // EF Core with SQLite
        var connectionString = configuration.GetConnectionString("DefaultConnection")
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
