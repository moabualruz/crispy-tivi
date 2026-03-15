namespace Crispy.Application.Player.Models;

/// <summary>
/// The type of content being played — drives player behaviour (timeshift eligibility, resume, etc.).
/// Renamed from ContentType to avoid ambiguity with Crispy.Domain.Enums.ContentType.
/// </summary>
public enum PlaybackContentType
{
    LiveTv,
    Vod,
    Radio,
}

/// <summary>
/// Everything the player needs to start playback of a single piece of content.
/// </summary>
/// <param name="Url">Direct stream URL (HLS, DASH, RTSP, HTTP progressive, etc.).</param>
/// <param name="ContentType">What category of content this is.</param>
/// <param name="Title">Optional display title shown on the OSD and media session notification.</param>
/// <param name="ChannelLogoUrl">Optional channel/artwork image URL for the OSD and lock-screen art.</param>
/// <param name="ResumeAt">Position at which to start playback (TimeSpan.Zero = from the beginning).</param>
/// <param name="HttpHeaders">Extra HTTP headers forwarded to the streaming engine (auth tokens, referrer, etc.).</param>
/// <param name="UserAgent">Custom User-Agent header; overrides the default if set.</param>
/// <param name="EnableTimeshift">Whether the timeshift ring buffer should be started alongside playback.</param>
/// <param name="JellyfinItemId">Jellyfin item id used for watch-progress reporting; null for IPTV sources.</param>
public sealed record PlaybackRequest(
    string Url,
    PlaybackContentType ContentType,
    string? Title = null,
    string? ChannelLogoUrl = null,
    TimeSpan ResumeAt = default,
    Dictionary<string, string>? HttpHeaders = null,
    string? UserAgent = null,
    bool EnableTimeshift = false,
    string? JellyfinItemId = null);
