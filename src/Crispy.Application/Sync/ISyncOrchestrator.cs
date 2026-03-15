namespace Crispy.Application.Sync;

/// <summary>
/// Manages the periodic background sync loop (startup sync + 4-hour interval).
/// </summary>
public interface ISyncOrchestrator
{
    /// <summary>Starts the background sync loop. Performs an immediate sync on startup.</summary>
    Task StartAsync(CancellationToken ct = default);

    /// <summary>Gracefully stops the background sync loop.</summary>
    Task StopAsync();
}
