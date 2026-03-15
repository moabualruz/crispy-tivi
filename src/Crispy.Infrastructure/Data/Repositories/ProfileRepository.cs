using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of the profile repository.
/// </summary>
public class ProfileRepository : IProfileRepository
{
    private readonly IDbContextFactory<AppDbContext> _contextFactory;

    /// <summary>
    /// Creates a new ProfileRepository.
    /// </summary>
    public ProfileRepository(IDbContextFactory<AppDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    /// <inheritdoc />
    public async Task<Profile?> GetByIdAsync(int id)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        return await context.Profiles
            .Include(p => p.Settings)
            .FirstOrDefaultAsync(p => p.Id == id);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Profile>> GetAllAsync()
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        return await context.Profiles
            .OrderBy(p => p.Name)
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task<Profile> CreateAsync(Profile profile)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        context.Profiles.Add(profile);
        await context.SaveChangesAsync();
        return profile;
    }

    /// <inheritdoc />
    public async Task UpdateAsync(Profile profile)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        context.Profiles.Update(profile);
        await context.SaveChangesAsync();
    }

    /// <inheritdoc />
    public async Task DeleteAsync(int id)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        var profile = await context.Profiles.FindAsync(id);
        if (profile is not null)
        {
            profile.DeletedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
        }
    }
}
