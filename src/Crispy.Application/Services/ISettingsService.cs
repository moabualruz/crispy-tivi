using Crispy.Domain.Enums;

namespace Crispy.Application.Services;

/// <summary>
/// Application service for typed settings access.
/// </summary>
public interface ISettingsService
{
    /// <summary>
    /// Gets a typed setting value, returning the default if not found.
    /// </summary>
    Task<T> GetAsync<T>(string key, T defaultValue, int? profileId = null);

    /// <summary>
    /// Sets a typed setting value (serialized as JSON).
    /// </summary>
    Task SetAsync<T>(string key, T value, int? profileId = null);

    /// <summary>
    /// Gets the current theme variant for a profile.
    /// </summary>
    Task<ThemeVariant> GetThemeAsync(int? profileId = null);

    /// <summary>
    /// Sets the theme variant for a profile.
    /// </summary>
    Task SetThemeAsync(ThemeVariant theme, int? profileId = null);

    /// <summary>
    /// Gets the locale string for a profile (e.g., "en", "ar").
    /// </summary>
    Task<string> GetLocaleAsync(int? profileId = null);

    /// <summary>
    /// Sets the locale for a profile.
    /// </summary>
    Task SetLocaleAsync(string locale, int? profileId = null);
}
