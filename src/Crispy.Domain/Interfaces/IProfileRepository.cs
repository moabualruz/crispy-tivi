using Crispy.Domain.Entities;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository for user profile management.
/// </summary>
public interface IProfileRepository
{
    /// <summary>
    /// Gets a profile by its ID.
    /// </summary>
    Task<Profile?> GetByIdAsync(int id);

    /// <summary>
    /// Gets all profiles.
    /// </summary>
    Task<IReadOnlyList<Profile>> GetAllAsync();

    /// <summary>
    /// Creates a new profile.
    /// </summary>
    Task<Profile> CreateAsync(Profile profile);

    /// <summary>
    /// Updates an existing profile.
    /// </summary>
    Task UpdateAsync(Profile profile);

    /// <summary>
    /// Soft-deletes a profile by ID.
    /// </summary>
    Task DeleteAsync(int id);
}
