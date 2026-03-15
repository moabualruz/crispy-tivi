using System.Collections.ObjectModel;
using System.Reflection;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Configuration;
using Crispy.Application.Services;
using Crispy.Domain.Enums;
using Crispy.UI.Services;
using Crispy.UI.Themes;

using FluentIcons.Common;
using Microsoft.Extensions.Options;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the Settings screen with two-panel layout.
/// </summary>
public partial class SettingsViewModel : ViewModelBase
{
    private readonly IThemeService _themeService;
    private readonly ILocalizationService _localizationService;
    private readonly ISettingsService _settingsService;
    private readonly FeatureFlagOptions _featureFlags;

    /// <summary>
    /// Creates a new SettingsViewModel.
    /// </summary>
    public SettingsViewModel(
        IThemeService themeService,
        ILocalizationService localizationService,
        ISettingsService settingsService,
        IOptions<FeatureFlagOptions> featureFlagOptions)
    {
        Title = "Settings";
        _themeService = themeService;
        _localizationService = localizationService;
        _settingsService = settingsService;
        _featureFlags = featureFlagOptions.Value;

        Categories =
        [
            new SettingsCategory("General", Symbol.Settings, "SettingsGeneral"),
            new SettingsCategory("Sources", Symbol.Globe, "SettingsSources"),
            new SettingsCategory("Playback", Symbol.Play, "SettingsPlayback"),
            new SettingsCategory("Data & Sync", Symbol.ArrowSync, "SettingsDataSync"),
            new SettingsCategory("Advanced", Symbol.Wrench, "SettingsAdvanced"),
            new SettingsCategory("About", Symbol.Info, "SettingsAbout"),
        ];

        SelectedCategory = Categories[0];

        // Sync initial values from services
        _selectedTheme = _themeService.CurrentTheme;
        _selectedLocaleOption = AvailableLocales.FirstOrDefault(
            l => l.Code == _localizationService.CurrentLocale) ?? AvailableLocales[0];
        _selectedAccentIndex = _themeService.SelectedAccentIndex;
        _isReducedMotion = _themeService.IsReducedMotion;
    }

    /// <summary>
    /// Available settings categories.
    /// </summary>
    public ObservableCollection<SettingsCategory> Categories { get; }

    /// <summary>
    /// Currently selected settings category.
    /// </summary>
    [ObservableProperty]
    private SettingsCategory? _selectedCategory;

    /// <summary>
    /// Currently selected theme variant.
    /// </summary>
    [ObservableProperty]
    private ThemeVariant _selectedTheme;

    /// <summary>
    /// Currently selected locale option.
    /// </summary>
    [ObservableProperty]
    private LocaleOption _selectedLocaleOption;

    /// <summary>
    /// Currently selected accent color palette index.
    /// </summary>
    [ObservableProperty]
    private int _selectedAccentIndex;

    /// <summary>
    /// Whether reduced motion is enabled.
    /// </summary>
    [ObservableProperty]
    private bool _isReducedMotion;

    /// <summary>
    /// Available locales with native names (as bindable records).
    /// </summary>
    public IReadOnlyList<LocaleOption> AvailableLocales { get; } =
        [
            new("en", "English"),
            new("ar", "\u0627\u0644\u0639\u0631\u0628\u064a\u0629"),
            new("tr", "T\u00fcrk\u00e7e"),
            new("fr", "Fran\u00e7ais"),
            new("de", "Deutsch"),
        ];

    /// <summary>
    /// Available theme variants.
    /// </summary>
    public IReadOnlyList<ThemeVariant> AvailableThemes { get; } =
        [ThemeVariant.Dark, ThemeVariant.OledBlack, ThemeVariant.Light];

    /// <summary>
    /// Accent color palette for display.
    /// </summary>
    public Avalonia.Media.Color[] AccentPalette => DesignTokens.AccentPalette;

    /// <summary>
    /// Whether debug diagnostics feature flag is enabled.
    /// </summary>
    public bool IsDebugDiagnosticsEnabled =>
        _featureFlags.DebugDiagnostics.IsEnabledForCurrentPlatform();

    /// <summary>
    /// Application version string.
    /// </summary>
    public string AppVersion =>
        Assembly.GetEntryAssembly()?.GetName().Version?.ToString() ?? "1.0.0";

    /// <summary>
    /// Application build date string.
    /// </summary>
    public string BuildDate =>
        Assembly.GetEntryAssembly()
            ?.GetCustomAttribute<AssemblyInformationalVersionAttribute>()
            ?.InformationalVersion ?? DateTime.UtcNow.ToString("yyyy-MM-dd");

    partial void OnSelectedThemeChanged(ThemeVariant value)
    {
        _ = _themeService.SetThemeAsync(value);
    }

    partial void OnSelectedLocaleOptionChanged(LocaleOption value)
    {
        _ = _localizationService.SetLocaleAsync(value.Code);
    }

    partial void OnSelectedAccentIndexChanged(int value)
    {
        _ = _themeService.SetAccentColorAsync(value);
    }

    partial void OnIsReducedMotionChanged(bool value)
    {
        _ = _themeService.SetReducedMotionAsync(value);
    }

    /// <summary>
    /// Resets settings for the current category.
    /// </summary>
    [RelayCommand]
    private async Task ResetCategoryAsync()
    {
        if (SelectedCategory is null)
        {
            return;
        }

        // Reset general settings to defaults
        if (SelectedCategory.Name == "General")
        {
            SelectedTheme = ThemeVariant.Dark;
            SelectedLocaleOption = AvailableLocales[0];
            SelectedAccentIndex = 0;
            IsReducedMotion = false;
        }

        await Task.CompletedTask;
    }

    /// <summary>
    /// Factory resets all settings to defaults.
    /// </summary>
    [RelayCommand]
    private async Task FactoryResetAsync()
    {
        SelectedTheme = ThemeVariant.Dark;
        SelectedLocaleOption = AvailableLocales[0];
        SelectedAccentIndex = 0;
        IsReducedMotion = false;
        SelectedCategory = Categories[0];
        await Task.CompletedTask;
    }
}

/// <summary>
/// Represents a settings category with name, icon, and localization key.
/// </summary>
/// <param name="Name">Display name of the category.</param>
/// <param name="Icon">Fluent icon symbol for the category.</param>
/// <param name="LocalizationKey">RESX localization key for the category name.</param>
public record SettingsCategory(string Name, FluentIcons.Common.Symbol Icon, string LocalizationKey);

/// <summary>
/// Bindable locale option for ComboBox display.
/// </summary>
/// <param name="Code">Locale code (e.g., "en", "ar").</param>
/// <param name="NativeName">Display name in the locale's native language.</param>
public record LocaleOption(string Code, string NativeName);
