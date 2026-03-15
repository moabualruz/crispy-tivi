using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// SQLite-backed implementation of ISavedLayoutRepository (PLR-42).
/// </summary>
public sealed class SavedLayoutRepository : ISavedLayoutRepository
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    /// <summary>Initializes a new instance of <see cref="SavedLayoutRepository"/>.</summary>
    public SavedLayoutRepository(IDbContextFactory<AppDbContext> dbFactory)
    {
        _dbFactory = dbFactory;
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<SavedLayout>> GetAllAsync(string profileId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        return await db.SavedLayouts
            .Where(l => l.ProfileId == profileId)
            .OrderByDescending(l => l.CreatedAt)
            .ToListAsync()
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task SaveAsync(SavedLayout layout)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var existing = await db.SavedLayouts.FindAsync(layout.Id).ConfigureAwait(false);
        if (existing is not null)
        {
            existing.Name = layout.Name;
            existing.Layout = layout.Layout;
            existing.StreamsJson = layout.StreamsJson;
        }
        else
        {
            db.SavedLayouts.Add(layout);
        }

        await db.SaveChangesAsync().ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task DeleteAsync(string layoutId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var layout = await db.SavedLayouts.FindAsync(layoutId).ConfigureAwait(false);
        if (layout is not null)
        {
            db.SavedLayouts.Remove(layout);
            await db.SaveChangesAsync().ConfigureAwait(false);
        }
    }
}
