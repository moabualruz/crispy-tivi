using Microsoft.Extensions.DependencyInjection;

namespace Crispy.UI;

/// <summary>
/// Registers UI layer services (ViewModels, navigation, etc.).
/// </summary>
public static class DependencyInjection
{
    /// <summary>
    /// Adds UI services to the DI container.
    /// Plan 02 adds navigation services, Plan 03 adds theme/localization.
    /// </summary>
    public static IServiceCollection AddUiServices(this IServiceCollection services)
    {
        return services;
    }
}
