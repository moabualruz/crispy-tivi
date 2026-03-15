using Crispy.Domain.Entities;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository contract for channel persistence and retrieval.
/// </summary>
public interface IChannelRepository
{
    /// <summary>Gets a channel by its primary key.</summary>
    Task<Channel?> GetByIdAsync(int id, CancellationToken ct = default);

    /// <summary>Returns all channels for a given source, including their stream endpoints.</summary>
    Task<IReadOnlyList<Channel>> GetBySourceAsync(int sourceId, CancellationToken ct = default);

    /// <summary>Bulk-upserts channels from a parse result, returning the count of rows affected.</summary>
    Task<int> UpsertRangeAsync(IEnumerable<Channel> channels, CancellationToken ct = default);

    /// <summary>Increments MissedSyncCount for all channels from a source that were absent in the last sync.</summary>
    Task IncrementMissedSyncAsync(int sourceId, IEnumerable<string> presentTvgIds, CancellationToken ct = default);

    /// <summary>Soft-deletes channels whose MissedSyncCount exceeds the threshold.</summary>
    Task SoftRemoveExpiredAsync(int sourceId, int threshold, CancellationToken ct = default);
}
