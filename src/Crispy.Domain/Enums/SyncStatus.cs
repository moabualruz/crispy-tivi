namespace Crispy.Domain.Enums;

/// <summary>
/// Terminal or in-progress state of a source synchronisation run.
/// </summary>
public enum SyncStatus
{
    /// <summary>Sync is currently in progress.</summary>
    Running = 0,

    /// <summary>Sync completed successfully.</summary>
    Completed = 1,

    /// <summary>Sync failed with an error.</summary>
    Failed = 2,

    /// <summary>Sync was cancelled by the user or system.</summary>
    Cancelled = 3,
}
