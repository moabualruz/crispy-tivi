namespace Crispy.Application.Sync;

/// <summary>
/// High-level sync operations exposed to the UI and background scheduler.
/// </summary>
public interface ISyncService
{
    /// <summary>Synchronises a single source by its primary key.</summary>
    Task SyncSourceAsync(int sourceId, CancellationToken ct = default);

    /// <summary>Synchronises all enabled sources concurrently.</summary>
    Task SyncAllAsync(CancellationToken ct = default);

    /// <summary>Requests cancellation of an in-progress sync for a source.</summary>
    Task CancelAsync(int sourceId);
}
