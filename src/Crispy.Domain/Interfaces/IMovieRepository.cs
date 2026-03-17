using Crispy.Domain.Entities;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository contract for VOD movie persistence and retrieval.
/// </summary>
public interface IMovieRepository
{
    /// <summary>Gets a movie by its primary key.</summary>
    Task<Movie?> GetByIdAsync(int id, CancellationToken ct = default);

    /// <summary>Returns all movies for a given source.</summary>
    Task<IReadOnlyList<Movie>> GetBySourceAsync(int sourceId, CancellationToken ct = default);

    /// <summary>Returns all movies across all sources.</summary>
    Task<IReadOnlyList<Movie>> GetAllAsync(CancellationToken ct = default);

    /// <summary>Bulk-upserts movies from a parse result.</summary>
    Task<int> UpsertRangeAsync(IEnumerable<Movie> movies, CancellationToken ct = default);
}
