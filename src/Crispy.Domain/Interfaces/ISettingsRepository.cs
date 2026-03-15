using Crispy.Domain.Entities;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository for key-value settings with optional profile scoping.
/// </summary>
public interface ISettingsRepository
{
    /// <summary>
    /// Gets a setting by key, optionally scoped to a profile.
    /// </summary>
    Task<Setting?> GetAsync(string key, int? profileId = null);

    /// <summary>
    /// Gets all settings, optionally filtered by profile.
    /// </summary>
    Task<IReadOnlyList<Setting>> GetAllAsync(int? profileId = null);

    /// <summary>
    /// Creates or updates a setting value.
    /// </summary>
    Task SetAsync(string key, string value, int? profileId = null);

    /// <summary>
    /// Deletes a specific setting.
    /// </summary>
    Task DeleteAsync(string key, int? profileId = null);

    /// <summary>
    /// Resets all settings matching a category prefix (e.g., "player.").
    /// </summary>
    Task ResetCategoryAsync(string categoryPrefix, int? profileId = null);

    /// <summary>
    /// Resets all settings for the given profile (or global if null).
    /// </summary>
    Task ResetAllAsync(int? profileId = null);
}
