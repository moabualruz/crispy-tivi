namespace Crispy.Application.Player.Models;

/// <summary>
/// A single item in the player queue (e.g. next episodes in a series season).
/// </summary>
/// <param name="Id">Unique item identifier (Jellyfin episode id or stream URL).</param>
/// <param name="Title">Episode or content title.</param>
/// <param name="EpisodeNumber">Episode number within the season, null for non-series content.</param>
/// <param name="Duration">Total duration; TimeSpan.Zero if unknown.</param>
/// <param name="ThumbnailUrl">Optional thumbnail image URL.</param>
/// <param name="Request">The playback request to start when this item is selected.</param>
/// <param name="IsCurrentlyPlaying">True when this is the item currently playing.</param>
public sealed record QueueItem(
    string Id,
    string Title,
    int? EpisodeNumber,
    TimeSpan Duration,
    string? ThumbnailUrl,
    PlaybackRequest Request,
    bool IsCurrentlyPlaying);
