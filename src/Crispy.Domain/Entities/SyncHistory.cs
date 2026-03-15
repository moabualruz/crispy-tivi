using Crispy.Domain.Enums;

namespace Crispy.Domain.Entities;

/// <summary>
/// Audit record of a single source synchronisation run.
/// </summary>
public class SyncHistory : BaseEntity
{
    /// <summary>Source that was synchronised.</summary>
    public required int SourceId { get; set; }

    /// <summary>Navigation property to the source.</summary>
    public Source? Source { get; set; }

    /// <summary>UTC time the sync run started.</summary>
    public DateTime StartedAt { get; set; }

    /// <summary>UTC time the sync run ended (null while still running).</summary>
    public DateTime? CompletedAt { get; set; }

    /// <summary>Terminal status of the sync run.</summary>
    public SyncStatus Status { get; set; }

    /// <summary>Number of channels upserted during the sync.</summary>
    public int ChannelCount { get; set; }

    /// <summary>Number of VOD items (movies + episodes) upserted during the sync.</summary>
    public int VodCount { get; set; }

    /// <summary>Number of EPG programmes upserted during the sync.</summary>
    public int EpgCount { get; set; }

    /// <summary>Error message when Status is Failed, otherwise null.</summary>
    public string? ErrorMessage { get; set; }

    /// <summary>Wall-clock duration of the sync run in milliseconds.</summary>
    public long DurationMs { get; set; }
}
