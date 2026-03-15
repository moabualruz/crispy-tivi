using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// SQLite-backed implementation of IBookmarkRepository (PLR-41).
/// </summary>
public sealed class BookmarkRepository : IBookmarkRepository
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    /// <summary>Initializes a new instance of <see cref="BookmarkRepository"/>.</summary>
    public BookmarkRepository(IDbContextFactory<AppDbContext> dbFactory)
    {
        _dbFactory = dbFactory;
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Bookmark>> GetForContentAsync(
        string contentId,
        ContentType type,
        string profileId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        return await db.Bookmarks
            .Where(b => b.ContentId == contentId
                     && b.ContentType == type
                     && b.ProfileId == profileId)
            .OrderBy(b => b.PositionMs)
            .ToListAsync()
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task AddAsync(Bookmark bookmark)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);
        db.Bookmarks.Add(bookmark);
        await db.SaveChangesAsync().ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task DeleteAsync(string bookmarkId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var bookmark = await db.Bookmarks.FindAsync(bookmarkId).ConfigureAwait(false);
        if (bookmark is not null)
        {
            db.Bookmarks.Remove(bookmark);
            await db.SaveChangesAsync().ConfigureAwait(false);
        }
    }
}
