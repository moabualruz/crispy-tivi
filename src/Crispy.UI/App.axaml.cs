using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Data.Core.Plugins;
using Avalonia.Markup.Xaml;

using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using Microsoft.Extensions.DependencyInjection;

namespace Crispy.UI;

/// <summary>
/// Avalonia application entry point.
/// </summary>
public partial class App : Avalonia.Application
{
    /// <summary>
    /// The application service provider. Set by the platform entry point.
    /// </summary>
    public static IServiceProvider? Services { get; set; }

    /// <inheritdoc />
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);

        // Register the DI-aware ViewLocator
        if (Services is not null)
        {
            var viewLocator = Services.GetRequiredService<ViewLocator>();
            DataTemplates.Add(viewLocator);
        }
    }

    /// <inheritdoc />
    public override void OnFrameworkInitializationCompleted()
    {
        // Initialize theme and localization AFTER XAML is loaded
        // (must happen here, not in Program.cs, because Application.Current is needed)
        if (Services is not null)
        {
            var themeService = Services.GetRequiredService<Services.IThemeService>();
            themeService.InitializeAsync().GetAwaiter().GetResult();

            var localizationService = Services.GetRequiredService<Services.ILocalizationService>();
            localizationService.InitializeAsync().GetAwaiter().GetResult();
        }

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            // Avoid duplicate validations from both Avalonia and CommunityToolkit.
            DisableAvaloniaDataAnnotationValidation();

            var mainViewModel = Services?.GetRequiredService<MainViewModel>();

            desktop.MainWindow = new MainWindow
            {
                DataContext = mainViewModel,
            };
        }
        else if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            var mainViewModel = Services?.GetRequiredService<MainViewModel>();

            singleView.MainView = new MainView
            {
                DataContext = mainViewModel,
            };
        }

        base.OnFrameworkInitializationCompleted();
    }

    private static void DisableAvaloniaDataAnnotationValidation()
    {
        var pluginsToRemove = BindingPlugins.DataValidators
            .OfType<DataAnnotationsValidationPlugin>()
            .ToArray();

        foreach (var plugin in pluginsToRemove)
        {
            BindingPlugins.DataValidators.Remove(plugin);
        }
    }
}
