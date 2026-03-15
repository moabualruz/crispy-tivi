using Avalonia;
using Avalonia.Markup.Xaml.Styling;
using Avalonia.Media;
using Avalonia.Styling;

using Crispy.Application.Services;
using Crispy.Domain.Enums;
using Crispy.UI.Themes;

using ThemeVariant = Crispy.Domain.Enums.ThemeVariant;

namespace Crispy.UI.Services;

/// <summary>
/// Runtime theme switching with persistence via ISettingsService.
/// Swaps ResourceDictionaries in Application.Current.Resources.MergedDictionaries.
/// </summary>
public class ThemeService : IThemeService
{
    private const string ReducedMotionKey = "reduced_motion";
    private const string AccentIndexKey = "accent_index";

    private static readonly Dictionary<ThemeVariant, string> ThemeUris = new()
    {
        [ThemeVariant.Dark] = "avares://Crispy.UI/Themes/DarkTheme.axaml",
        [ThemeVariant.OledBlack] = "avares://Crispy.UI/Themes/OledBlackTheme.axaml",
        [ThemeVariant.Light] = "avares://Crispy.UI/Themes/LightTheme.axaml",
    };

    private readonly ISettingsService _settingsService;

    /// <summary>
    /// Creates a new ThemeService.
    /// </summary>
    public ThemeService(ISettingsService settingsService)
    {
        _settingsService = settingsService;
    }

    /// <inheritdoc />
    public ThemeVariant CurrentTheme { get; private set; } = ThemeVariant.Dark;

    /// <inheritdoc />
    public bool IsReducedMotion { get; private set; }

    /// <inheritdoc />
    public int SelectedAccentIndex { get; private set; }

    /// <inheritdoc />
    public event Action<ThemeVariant>? ThemeChanged;

    /// <inheritdoc />
    public async Task SetThemeAsync(ThemeVariant theme)
    {
        if (CurrentTheme == theme)
        {
            return;
        }

        CurrentTheme = theme;
        ApplyThemeResources(theme);
        await _settingsService.SetThemeAsync(theme);
        ThemeChanged?.Invoke(theme);
    }

    /// <inheritdoc />
    public async Task InitializeAsync()
    {
        var theme = await _settingsService.GetThemeAsync();
        CurrentTheme = theme;
        ApplyThemeResources(theme);

        IsReducedMotion = await _settingsService.GetAsync(ReducedMotionKey, false);
        SelectedAccentIndex = await _settingsService.GetAsync(AccentIndexKey, 0);

        if (SelectedAccentIndex >= 0 && SelectedAccentIndex < DesignTokens.AccentPalette.Length)
        {
            ApplyAccentColor(SelectedAccentIndex);
        }
    }

    /// <inheritdoc />
    public async Task SetReducedMotionAsync(bool enabled)
    {
        IsReducedMotion = enabled;
        await _settingsService.SetAsync(ReducedMotionKey, enabled);

        if (Avalonia.Application.Current?.Resources is { } resources)
        {
            resources["ReducedMotion"] = enabled;
        }
    }

    /// <inheritdoc />
    public async Task SetAccentColorAsync(int paletteIndex)
    {
        var clamped = Math.Clamp(paletteIndex, 0, DesignTokens.AccentPalette.Length - 1);
        SelectedAccentIndex = clamped;
        ApplyAccentColor(clamped);
        await _settingsService.SetAsync(AccentIndexKey, clamped);
    }

    private static void ApplyThemeResources(ThemeVariant theme)
    {
        if (Avalonia.Application.Current is not { } app)
        {
            return;
        }

        // Set Avalonia's built-in theme variant for FluentTheme
        app.RequestedThemeVariant = theme == ThemeVariant.Light
            ? Avalonia.Styling.ThemeVariant.Light
            : Avalonia.Styling.ThemeVariant.Dark;

        if (!ThemeUris.TryGetValue(theme, out var uri))
        {
            return;
        }

        // Remove existing theme dictionaries
        var merged = app.Resources.MergedDictionaries;
        var toRemove = merged
            .OfType<ResourceInclude>()
            .Where(r => r.Source?.ToString().Contains("Theme.axaml") == true)
            .ToList();

        foreach (var item in toRemove)
        {
            merged.Remove(item);
        }

        // Add the new theme dictionary
        var include = new ResourceInclude(new Uri("avares://Crispy.UI"))
        {
            Source = new Uri(uri),
        };
        merged.Insert(0, include);
    }

    private static void ApplyAccentColor(int index)
    {
        if (Avalonia.Application.Current?.Resources is not { } resources)
        {
            return;
        }

        var color = DesignTokens.AccentPalette[index];
        resources["AccentPrimary"] = color;
        resources["AccentPrimaryBrush"] = new SolidColorBrush(color);
    }
}
