namespace Crispy.Application.Player.Models;

/// <summary>
/// Discriminates the type of media in a watch history entry (PLR-48).
/// </summary>
public enum MediaType
{
    /// <summary>Live TV channel.</summary>
    Channel = 0,

    /// <summary>VOD movie.</summary>
    Movie = 1,

    /// <summary>Individual episode of a series.</summary>
    Episode = 2,
}

/// <summary>
/// Records a single playback session for any content type.
/// ID is the SHA-256 hash of the stream URL, first 8 bytes hex-encoded (PLR-47).
/// </summary>
public class WatchHistoryEntry
{
    /// <summary>SHA-256(streamUrl)[0..8] hex — stable across renames (PLR-47).</summary>
    public required string Id { get; set; }

    /// <summary>Content type discriminator (PLR-48).</summary>
    public MediaType MediaType { get; set; }

    /// <summary>Display name for the content.</summary>
    public required string Name { get; set; }

    /// <summary>The actual stream URL used for playback.</summary>
    public required string StreamUrl { get; set; }

    /// <summary>Poster/thumbnail URL.</summary>
    public string? PosterUrl { get; set; }

    /// <summary>Series-level poster (used when MediaType == Episode).</summary>
    public string? SeriesPosterUrl { get; set; }

    /// <summary>Playback position in milliseconds.</summary>
    public long PositionMs { get; set; }

    /// <summary>Total duration in milliseconds (0 for live channels).</summary>
    public long DurationMs { get; set; }

    /// <summary>UTC timestamp of the last watch activity.</summary>
    public DateTimeOffset LastWatched { get; set; }

    /// <summary>Parent series ID (null for non-episode content).</summary>
    public string? SeriesId { get; set; }

    /// <summary>Season number within the series (null for non-episode content).</summary>
    public int? SeasonNumber { get; set; }

    /// <summary>Episode number within the season (null for non-episode content).</summary>
    public int? EpisodeNumber { get; set; }

    /// <summary>Device identifier for multi-device sync.</summary>
    public required string DeviceId { get; set; }

    /// <summary>Human-readable device name.</summary>
    public required string DeviceName { get; set; }

    /// <summary>Profile this entry belongs to.</summary>
    public required string ProfileId { get; set; }

    /// <summary>Source (provider) this content came from.</summary>
    public required string SourceId { get; set; }

    // -------------------------------------------------------------------------
    // Computed properties (PLR-49)
    // -------------------------------------------------------------------------

    /// <summary>
    /// Playback progress as a fraction 0.0–1.0 (PLR-49).
    /// Returns 0.0 when DurationMs is 0 (live channels).
    /// </summary>
    public double Progress => DurationMs > 0 ? (double)PositionMs / DurationMs : 0.0;

    /// <summary>
    /// True when playback has started but is not yet complete (PLR-44).
    /// Progress must be > 0 and &lt; 0.95 (95 % threshold marks "watched").
    /// </summary>
    public bool IsInProgress => Progress > 0.0 && Progress < 0.95;
}
