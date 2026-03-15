using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Persistence contract for saved multiview layouts (PLR-42).
/// </summary>
public interface ISavedLayoutRepository
{
    /// <summary>
    /// Returns all saved layouts for the given profile, ordered by CreatedAt descending.
    /// </summary>
    Task<IReadOnlyList<SavedLayout>> GetAllAsync(string profileId);

    /// <summary>Upserts a layout by ID.</summary>
    Task SaveAsync(SavedLayout layout);

    /// <summary>Deletes a layout by ID.</summary>
    Task DeleteAsync(string layoutId);
}
