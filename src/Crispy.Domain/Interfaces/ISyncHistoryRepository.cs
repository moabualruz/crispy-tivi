using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository contract for sync audit history.
/// </summary>
public interface ISyncHistoryRepository
{
    /// <summary>Creates a new sync run record and returns its assigned Id.</summary>
    Task<int> BeginSyncAsync(int sourceId, CancellationToken ct = default);

    /// <summary>Updates a sync run record when the run completes (or fails).</summary>
    Task CompleteSyncAsync(
        int syncHistoryId,
        SyncStatus status,
        int channelCount,
        int vodCount,
        int epgCount,
        long durationMs,
        string? errorMessage = null,
        CancellationToken ct = default);

    /// <summary>Returns the most recent N sync history entries for a source.</summary>
    Task<IReadOnlyList<SyncHistory>> GetRecentAsync(int sourceId, int count = 10, CancellationToken ct = default);
}
