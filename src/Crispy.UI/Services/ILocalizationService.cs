namespace Crispy.UI.Services;

/// <summary>
/// Runtime locale switching with RTL support and persistence.
/// </summary>
public interface ILocalizationService
{
    /// <summary>
    /// Currently active locale code (e.g., "en", "ar").
    /// </summary>
    string CurrentLocale { get; }

    /// <summary>
    /// Whether the current locale uses right-to-left text direction.
    /// </summary>
    bool IsRightToLeft { get; }

    /// <summary>
    /// Switches the active locale, sets culture, and persists the choice.
    /// </summary>
    Task SetLocaleAsync(string cultureName);

    /// <summary>
    /// Loads the persisted locale on startup.
    /// </summary>
    Task InitializeAsync();

    /// <summary>
    /// Available locale options with native display names.
    /// </summary>
    IReadOnlyList<(string Code, string NativeName)> AvailableLocales { get; }

    /// <summary>
    /// Fired when the locale changes.
    /// </summary>
    event Action<string>? LocaleChanged;
}
