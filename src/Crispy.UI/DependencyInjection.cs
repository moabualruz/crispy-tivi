using CommunityToolkit.Mvvm.Messaging;

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
        services.AddTransient<PlayerViewModel>();
        services.AddTransient<TrackSelectorViewModel>();
        services.AddTransient<MultiviewViewModel>();
        services.AddSingleton<EqualizerOverlayViewModel>(); // singleton — EQ state persists across sessions
        services.AddSingleton<MiniPlayerViewModel>(); // singleton — shared state while browsing

        // Views (transient — resolved by ViewLocator)
        services.AddTransient<PlayerView>();
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

        return services;
    }
}
