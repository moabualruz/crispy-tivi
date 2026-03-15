using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of the settings repository.
/// </summary>
public class SettingsRepository : ISettingsRepository
{
    private readonly IDbContextFactory<AppDbContext> _contextFactory;

    /// <summary>
    /// Creates a new SettingsRepository.
    /// </summary>
    public SettingsRepository(IDbContextFactory<AppDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    /// <inheritdoc />
    public async Task<Setting?> GetAsync(string key, int? profileId = null)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        return await context.Settings
            .FirstOrDefaultAsync(s => s.Key == key && s.ProfileId == profileId);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Setting>> GetAllAsync(int? profileId = null)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        return await context.Settings
            .Where(s => s.ProfileId == profileId)
            .OrderBy(s => s.Key)
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task SetAsync(string key, string value, int? profileId = null)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        var existing = await context.Settings
            .FirstOrDefaultAsync(s => s.Key == key && s.ProfileId == profileId);

        if (existing is not null)
        {
            existing.Value = value;
        }
        else
        {
            context.Settings.Add(new Setting
            {
                Key = key,
                Value = value,
                ProfileId = profileId,
            });
        }

        await context.SaveChangesAsync();
    }

    /// <inheritdoc />
    public async Task DeleteAsync(string key, int? profileId = null)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        var setting = await context.Settings
            .FirstOrDefaultAsync(s => s.Key == key && s.ProfileId == profileId);

        if (setting is not null)
        {
            context.Settings.Remove(setting);
            await context.SaveChangesAsync();
        }
    }

    /// <inheritdoc />
    public async Task ResetCategoryAsync(string categoryPrefix, int? profileId = null)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        var settings = await context.Settings
            .Where(s => s.Key.StartsWith(categoryPrefix) && s.ProfileId == profileId)
            .ToListAsync();

        context.Settings.RemoveRange(settings);
        await context.SaveChangesAsync();
    }

    /// <inheritdoc />
    public async Task ResetAllAsync(int? profileId = null)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        var settings = await context.Settings
            .Where(s => s.ProfileId == profileId)
            .ToListAsync();

        context.Settings.RemoveRange(settings);
        await context.SaveChangesAsync();
    }
}
