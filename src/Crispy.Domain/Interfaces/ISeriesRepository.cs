using Crispy.Domain.Entities;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository contract for series and episode persistence and retrieval.
/// </summary>
public interface ISeriesRepository
{
    /// <summary>Gets a series by its primary key, optionally including episodes.</summary>
    Task<Series?> GetByIdAsync(int id, bool includeEpisodes = false, CancellationToken ct = default);

    /// <summary>Returns all series for a given source.</summary>
    Task<IReadOnlyList<Series>> GetBySourceAsync(int sourceId, CancellationToken ct = default);

    /// <summary>Bulk-upserts series from a parse result.</summary>
    Task<int> UpsertRangeAsync(IEnumerable<Series> series, CancellationToken ct = default);

    /// <summary>Bulk-upserts episodes for a given series.</summary>
    Task<int> UpsertEpisodesAsync(IEnumerable<Episode> episodes, CancellationToken ct = default);
}
