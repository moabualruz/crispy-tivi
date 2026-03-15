using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of the source repository.
/// </summary>
public class SourceRepository : ISourceRepository
{
    private readonly IDbContextFactory<AppDbContext> _contextFactory;

    /// <summary>
    /// Creates a new SourceRepository.
    /// </summary>
    public SourceRepository(IDbContextFactory<AppDbContext> contextFactory)
    {
        _contextFactory = contextFactory;
    }

    /// <inheritdoc />
    public async Task<Source?> GetByIdAsync(int id)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        return await context.Sources.FirstOrDefaultAsync(s => s.Id == id);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Source>> GetAllAsync()
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        return await context.Sources
            .OrderBy(s => s.SortOrder)
            .ThenBy(s => s.Name)
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Source>> GetByProfileAsync(int profileId)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        return await context.Sources
            .Where(s => s.ProfileId == profileId)
            .OrderBy(s => s.SortOrder)
            .ThenBy(s => s.Name)
            .ToListAsync();
    }

    /// <inheritdoc />
    public async Task<Source> CreateAsync(Source source)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        context.Sources.Add(source);
        await context.SaveChangesAsync();
        return source;
    }

    /// <inheritdoc />
    public async Task UpdateAsync(Source source)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        context.Sources.Update(source);
        await context.SaveChangesAsync();
    }

    /// <inheritdoc />
    public async Task DeleteAsync(int id)
    {
        await using var context = await _contextFactory.CreateDbContextAsync();
        var source = await context.Sources.FindAsync(id);
        if (source is not null)
        {
            source.DeletedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
        }
    }
}
