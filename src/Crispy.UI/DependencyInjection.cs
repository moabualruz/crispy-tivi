using CommunityToolkit.Mvvm.Messaging;

using Crispy.Application.Player;
using Crispy.UI.Controls;
using Crispy.UI.Navigation;
using Crispy.UI.Services;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using Microsoft.Extensions.DependencyInjection;

namespace Crispy.UI;

/// <summary>
/// Registers UI layer services (ViewModels, navigation, views).
/// </summary>
public static class DependencyInjection
{
    /// <summary>
    /// Adds UI services to the DI container.
    /// </summary>
    public static IServiceCollection AddUiServices(this IServiceCollection services)
    {
        // Theme & Localization
        services.AddSingleton<IThemeService, ThemeService>();
        services.AddSingleton<ILocalizationService, LocalizationService>();

        // Messaging
        services.AddSingleton<IMessenger>(WeakReferenceMessenger.Default);

        // Navigation
        services.AddSingleton<INavigationService, NavigationService>();
        services.AddSingleton<ViewLocator>();

        // ViewModels (transient — new instance per navigation)
        services.AddTransient<MainViewModel>();
        services.AddTransient<HomeViewModel>();
        services.AddTransient<LiveTvViewModel>();
        services.AddTransient<MoviesViewModel>();
        services.AddTransient<SeriesViewModel>();
        services.AddTransient<SearchViewModel>();
        services.AddTransient<SettingsViewModel>();
        services.AddTransient<SourcesViewModel>();
        services.AddTransient<AddSourceViewModel>();
        services.AddTransient<EpgViewModel>();
        services.AddSingleton<PlayerViewModel>(); // singleton — persists across navigation, direct play API
        services.AddSingleton<IPlayerController>(sp => sp.GetRequiredService<PlayerViewModel>());
        services.AddTransient<TrackSelectorViewModel>();
        services.AddTransient<MultiviewViewModel>();
        services.AddSingleton<EqualizerOverlayViewModel>(); // singleton — EQ state persists across sessions
        services.AddSingleton<MiniPlayerViewModel>(); // singleton — shared state while browsing
        services.AddSingleton<AppShellViewModel>(); // singleton — root shell, owns layer state

        // Video surface — singleton so VlcPlayerService can push frames to it
        services.AddSingleton<GpuVideoSurface>();
        services.AddSingleton<IVideoFrameReceiver>(sp => sp.GetRequiredService<GpuVideoSurface>());

        // Views (transient — resolved by ViewLocator)
        services.AddTransient<AppShell>();
        services.AddTransient<TrackSelectorView>();
        services.AddTransient<MiniPlayerView>();
        services.AddTransient<MainView>();
        services.AddTransient<HomeView>();
        services.AddTransient<LiveTvView>();
        services.AddTransient<MoviesView>();
        services.AddTransient<SeriesView>();
        services.AddTransient<SearchView>();
        services.AddTransient<SettingsView>();
        services.AddTransient<AddSourceView>();
        services.AddTransient<EpgView>();
        services.AddTransient<MultiviewView>();

        return services;
    }
}
