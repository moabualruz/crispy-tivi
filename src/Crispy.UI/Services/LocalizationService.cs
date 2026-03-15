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
            return;
        }

        if (CurrentLocale == cultureName)
        {
            return;
        }

        CurrentLocale = cultureName;
        ApplyCulture(cultureName);
        await _settingsService.SetLocaleAsync(cultureName);
        LocaleChanged?.Invoke(cultureName);
    }

    /// <inheritdoc />
    public async Task InitializeAsync()
    {
        var locale = await _settingsService.GetLocaleAsync();
        if (ValidCodes.Contains(locale))
        {
            CurrentLocale = locale;
            ApplyCulture(locale);
        }
    }

    private void ApplyCulture(string cultureName)
    {
        var culture = new CultureInfo(cultureName);
        CultureInfo.CurrentCulture = culture;
        CultureInfo.CurrentUICulture = culture;
        // TODO: Strings.Culture = culture; — requires resource files (Plan 03)

        IsRightToLeft = culture.TextInfo.IsRightToLeft;
    }
}
