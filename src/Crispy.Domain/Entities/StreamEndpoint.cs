using Crispy.Domain.Enums;

namespace Crispy.Domain.Entities;

/// <summary>
/// A specific playable URL for a channel, provided by one source.
/// A deduplicated channel may have multiple endpoints ranked by priority.
/// </summary>
public class StreamEndpoint : BaseEntity
{
    /// <summary>FK to the owning channel.</summary>
    public required int ChannelId { get; set; }

    /// <summary>Navigation property to the channel.</summary>
    public Channel? Channel { get; set; }

    /// <summary>FK to the source that provided this endpoint.</summary>
    public required int SourceId { get; set; }

    /// <summary>Navigation property to the source.</summary>
    public Source? Source { get; set; }

    /// <summary>Playable stream URL.</summary>
    public required string Url { get; set; }

    /// <summary>Detected or declared stream container format.</summary>
    public StreamFormat Format { get; set; } = StreamFormat.Unknown;

    /// <summary>JSON-serialised HTTP headers to include when opening the stream.</summary>
    public string? HttpHeaders { get; set; }

    /// <summary>Lower value = higher priority; tried first during playback.</summary>
    public int Priority { get; set; }

    /// <summary>UTC time the stream last responded successfully to a playback probe.</summary>
    public DateTimeOffset? LastSuccessAt { get; set; }

    /// <summary>Consecutive playback failure count; triggers priority demotion at threshold.</summary>
    public int FailureCount { get; set; }
}
