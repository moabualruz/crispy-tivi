using Crispy.Application.Services;

using Microsoft.Extensions.DependencyInjection;

namespace Crispy.Application;

/// <summary>
/// Registers application layer services.
/// </summary>
public static class DependencyInjection
{
    /// <summary>
    /// Adds application services to the DI container.
    /// </summary>
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<ISettingsService, SettingsService>();
        return services;
    }
}
