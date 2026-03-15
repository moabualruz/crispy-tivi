namespace Crispy.Application.Sync;

/// <summary>
/// Configuration options for the sync engine, bindable from appsettings.json.
/// </summary>
public sealed class SyncOptions
{
    /// <summary>Configuration section name.</summary>
    public const string Section = "Sync";

    /// <summary>How often sources are automatically re-synced. Defaults to 4 hours.</summary>
    public TimeSpan SyncInterval { get; set; } = TimeSpan.FromHours(4);

    /// <summary>Number of items processed per database batch during bulk insert. Defaults to 500.</summary>
    public int BatchSize { get; set; } = 500;

    /// <summary>
    /// How many consecutive syncs a channel must be absent from the feed before it is
    /// soft-removed from the database. Defaults to 2.
    /// </summary>
    public int MaxMissedSyncsBeforeSoftRemove { get; set; } = 2;

    /// <summary>
    /// Days after soft-removal before a channel is permanently deleted. Defaults to 7.
    /// </summary>
    public int DaysBeforeAutoDelete { get; set; } = 7;
}
