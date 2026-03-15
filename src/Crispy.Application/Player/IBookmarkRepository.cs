using Crispy.Application.Player.Models;
using Crispy.Domain.Enums;

namespace Crispy.Application.Player;

/// <summary>
/// Persistence contract for playback bookmarks (PLR-41).
/// </summary>
public interface IBookmarkRepository
{
    /// <summary>
    /// Returns all bookmarks for the given content item and profile, ordered by position ascending.
    /// </summary>
    Task<IReadOnlyList<Bookmark>> GetForContentAsync(string contentId, ContentType type, string profileId);

    /// <summary>Persists a new bookmark.</summary>
    Task AddAsync(Bookmark bookmark);

    /// <summary>Deletes a bookmark by ID.</summary>
    Task DeleteAsync(string bookmarkId);
}
