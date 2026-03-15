using System.Text.Json;

using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;

namespace Crispy.Application.Services;

/// <summary>
/// Settings service that wraps the repository with typed JSON serialization.
/// </summary>
public class SettingsService : ISettingsService
{
    private const string ThemeKey = "theme";
    private const string LocaleKey = "locale";

    private readonly ISettingsRepository _repository;

    /// <summary>
    /// Creates a new SettingsService.
    /// </summary>
    public SettingsService(ISettingsRepository repository)
    {
        _repository = repository;
    }

    /// <inheritdoc />
    public async Task<T> GetAsync<T>(string key, T defaultValue, int? profileId = null)
    {
        var setting = await _repository.GetAsync(key, profileId);
        if (setting is null)
        {
            return defaultValue;
        }

        try
        {
            var result = JsonSerializer.Deserialize<T>(setting.Value);
            return result ?? defaultValue;
        }
        catch (JsonException)
        {
            return defaultValue;
        }
    }

    /// <inheritdoc />
    public async Task SetAsync<T>(string key, T value, int? profileId = null)
    {
        var json = JsonSerializer.Serialize(value);
        await _repository.SetAsync(key, json, profileId);
    }

    /// <inheritdoc />
    public async Task<ThemeVariant> GetThemeAsync(int? profileId = null)
    {
        return await GetAsync(ThemeKey, ThemeVariant.Dark, profileId);
    }

    /// <inheritdoc />
    public async Task SetThemeAsync(ThemeVariant theme, int? profileId = null)
    {
        await SetAsync(ThemeKey, theme, profileId);
    }

    /// <inheritdoc />
    public async Task<string> GetLocaleAsync(int? profileId = null)
    {
        return await GetAsync(LocaleKey, "en", profileId);
    }

    /// <inheritdoc />
    public async Task SetLocaleAsync(string locale, int? profileId = null)
    {
        await SetAsync(LocaleKey, locale, profileId);
    }
}
