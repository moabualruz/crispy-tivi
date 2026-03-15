using Crispy.Domain.Entities;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository for content source management.
/// </summary>
public interface ISourceRepository
{
    /// <summary>
    /// Gets a source by its ID.
    /// </summary>
    Task<Source?> GetByIdAsync(int id);

    /// <summary>
    /// Gets all sources.
    /// </summary>
    Task<IReadOnlyList<Source>> GetAllAsync();

    /// <summary>
    /// Gets all sources belonging to a specific profile.
    /// </summary>
    Task<IReadOnlyList<Source>> GetByProfileAsync(int profileId);

    /// <summary>
    /// Creates a new source.
    /// </summary>
    Task<Source> CreateAsync(Source source);

    /// <summary>
    /// Updates an existing source.
    /// </summary>
    Task UpdateAsync(Source source);

    /// <summary>
    /// Soft-deletes a source by ID.
    /// </summary>
    Task DeleteAsync(int id);
}
