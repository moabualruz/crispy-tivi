using System.Globalization;

using Crispy.Application.Services;

namespace Crispy.UI.Services;

/// <summary>
/// Runtime locale switching with RTL support.
/// Sets CultureInfo and FlowDirection, persists via ISettingsService.
/// </summary>
public class LocalizationService : ILocalizationService
{
    private static readonly IReadOnlyList<(string Code, string NativeName)> Locales =
    [
        ("en", "English"),
        ("ar", "\u0627\u0644\u0639\u0631\u0628\u064a\u0629"),
        ("tr", "T\u00fcrk\u00e7e"),
        ("fr", "Fran\u00e7ais"),
        ("de", "Deutsch"),
    ];

    private static readonly HashSet<string> ValidCodes = new(
        Locales.Select(l => l.Code),
        StringComparer.OrdinalIgnoreCase);

    private readonly ISettingsService _settingsService;

    /// <summary>
    /// Creates a new LocalizationService.
    /// </summary>
    public LocalizationService(ISettingsService settingsService)
    {
        _settingsService = settingsService;
    }

    /// <inheritdoc />
    public string CurrentLocale { get; private set; } = "en";

    /// <inheritdoc />
    public bool IsRightToLeft { get; private set; }

    /// <inheritdoc />
    public IReadOnlyList<(string Code, string NativeName)> AvailableLocales => Locales;

    /// <inheritdoc />
    public event Action<string>? LocaleChanged;

    /// <inheritdoc />
    public async Task SetLocaleAsync(string cultureName)
    {
        if (!ValidCodes.Contains(cultureName))
        {
            Console.WriteLine($"[Locale] SetLocaleAsync: invalid code '{cultureName}', ignoring");
            return;
        }

        if (CurrentLocale == cultureName)
        {
            Console.WriteLine($"[Locale] SetLocaleAsync: '{cultureName}' already active, no-op");
            return;
        }

        CurrentLocale = cultureName;
        ApplyCulture(cultureName);
        Console.WriteLine($"[Locale] Saving locale '{cultureName}' to DB");
        await _settingsService.SetLocaleAsync(cultureName);
        Console.WriteLine($"[Locale] Saved '{cultureName}' to DB successfully");
        LocaleChanged?.Invoke(cultureName);
    }

    /// <inheritdoc />
    public async Task InitializeAsync()
    {
        Console.WriteLine("[Locale] InitializeAsync: reading locale from DB");
        var locale = await _settingsService.GetLocaleAsync();
        Console.WriteLine($"[Locale] InitializeAsync: DB returned '{locale}'");
        if (ValidCodes.Contains(locale))
        {
            CurrentLocale = locale;
            ApplyCulture(locale);
            Console.WriteLine($"[Locale] Applied locale '{locale}'");
        }
        else
        {
            Console.WriteLine($"[Locale] '{locale}' not in ValidCodes — staying at default 'en'");
        }
    }

    private void ApplyCulture(string cultureName)
    {
        var culture = new CultureInfo(cultureName);
        CultureInfo.CurrentCulture = culture;
        CultureInfo.CurrentUICulture = culture;

        IsRightToLeft = culture.TextInfo.IsRightToLeft;

        // Apply FlowDirection to the main window
        if (Avalonia.Application.Current?.ApplicationLifetime
            is Avalonia.Controls.ApplicationLifetimes.IClassicDesktopStyleApplicationLifetime desktop
            && desktop.MainWindow is not null)
        {
            desktop.MainWindow.FlowDirection = IsRightToLeft
                ? Avalonia.Media.FlowDirection.RightToLeft
                : Avalonia.Media.FlowDirection.LeftToRight;
        }
    }
}
