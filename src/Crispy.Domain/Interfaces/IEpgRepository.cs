using Crispy.Domain.Entities;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository contract for EPG programme data stored in the dedicated epg.db.
/// </summary>
public interface IEpgRepository
{
    /// <summary>Returns programmes for a channel within a UTC time range.</summary>
    Task<IReadOnlyList<EpgProgramme>> GetProgrammesAsync(
        string channelId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken ct = default);

    /// <summary>Returns the current programme for a channel at the given UTC time.</summary>
    Task<EpgProgramme?> GetCurrentAsync(string channelId, DateTime atUtc, CancellationToken ct = default);

    /// <summary>Bulk-upserts EPG programmes, replacing the existing window for the affected channels.</summary>
    Task<int> UpsertRangeAsync(IEnumerable<EpgProgramme> programmes, CancellationToken ct = default);

    /// <summary>Deletes programmes older than the given UTC cutoff to keep epg.db lean.</summary>
    Task PurgeBeforeAsync(DateTime cutoffUtc, CancellationToken ct = default);
}
