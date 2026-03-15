using Crispy.Domain.Enums;

namespace Crispy.Domain.Entities;

/// <summary>
/// Records a playback event for any content type, enabling resume and watch-progress sync.
/// </summary>
public class WatchHistory : BaseEntity
{
    /// <summary>Profile that watched the content.</summary>
    public required int ProfileId { get; set; }

    /// <summary>Navigation property to the profile.</summary>
    public Profile? Profile { get; set; }

    /// <summary>Type discriminator for the watched content.</summary>
    public ContentType ContentType { get; set; }

    /// <summary>Primary key of the watched content item.</summary>
    public required int ContentId { get; set; }

    /// <summary>Playback position in milliseconds at the time this record was written.</summary>
    public long PositionMs { get; set; }

    /// <summary>Total content duration in milliseconds (may be 0 for live channels).</summary>
    public long DurationMs { get; set; }

    /// <summary>Completion percentage (0.0 – 1.0). 1.0 = watched to end.</summary>
    public double CompletionPct { get; set; }

    /// <summary>UTC time the playback session was recorded.</summary>
    public DateTime WatchedAt { get; set; }

    /// <summary>Source from which the content was streamed.</summary>
    public required int SourceId { get; set; }
}
