namespace Crispy.Application.Player.Models;

/// <summary>
/// Kind of media track exposed by the player.
/// </summary>
public enum TrackKind
{
    Audio,
    Subtitle,
    Video,
}

/// <summary>
/// Describes a single audio, subtitle, or video track available in the current media.
/// </summary>
/// <param name="Id">Track identifier used by the underlying player (e.g., LibVLC track id).</param>
/// <param name="Name">Human-readable track name.</param>
/// <param name="Language">BCP-47 language code (e.g., "en", "fr") or empty string if unknown.</param>
/// <param name="IsSelected">True when this track is the currently active track of its kind.</param>
/// <param name="Kind">Whether this is an audio, subtitle, or video track.</param>
public sealed record TrackInfo(
    int Id,
    string Name,
    string Language,
    bool IsSelected,
    TrackKind Kind);
