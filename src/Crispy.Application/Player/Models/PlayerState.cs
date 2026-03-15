namespace Crispy.Application.Player.Models;

/// <summary>
/// Full immutable snapshot of playback state — emitted on every state change via IPlayerService.StateChanged.
/// </summary>
/// <param name="Mode">Current playback mode (Live, Timeshifted, Catchup, Vod, Radio).</param>
/// <param name="IsPlaying">True when media is actively playing (not paused, not stopped).</param>
/// <param name="IsBuffering">True when the player is stalled waiting for data.</param>
/// <param name="IsMuted">True when audio output is muted.</param>
/// <param name="Volume">Playback volume in the range [0.0, 1.0].</param>
/// <param name="Rate">Playback speed multiplier (1.0 = normal, 0.5 = half-speed, 2.0 = double-speed).</param>
/// <param name="Position">Current playback position (meaningful only for VOD / catch-up / timeshift).</param>
/// <param name="Duration">Total media duration; TimeSpan.Zero for live streams with no known duration.</param>
/// <param name="IsLive">True when the stream has no fixed end (live TV, radio).</param>
/// <param name="Timeshift">Timeshift ring-buffer state; null when timeshift is not active.</param>
/// <param name="IsAudioOnly">True when IAudioStreamDetector classified this content as audio-only.</param>
/// <param name="ErrorMessage">Human-readable playback error description; null when no error.</param>
/// <param name="AudioTracks">Available audio tracks in the current media.</param>
/// <param name="SubtitleTracks">Available subtitle tracks in the current media.</param>
/// <param name="CurrentVideoWidth">Video frame width in pixels; null for audio-only or before first frame.</param>
/// <param name="CurrentVideoHeight">Video frame height in pixels; null for audio-only or before first frame.</param>
/// <param name="CurrentRequest">The request that initiated the current playback session; null when stopped.</param>
public sealed record PlayerState(
    PlaybackMode Mode,
    bool IsPlaying,
    bool IsBuffering,
    bool IsMuted,
    float Volume,
    float Rate,
    TimeSpan Position,
    TimeSpan Duration,
    bool IsLive,
    TimeshiftState? Timeshift,
    bool IsAudioOnly,
    string? ErrorMessage,
    IReadOnlyList<TrackInfo> AudioTracks,
    IReadOnlyList<TrackInfo> SubtitleTracks,
    int? CurrentVideoWidth,
    int? CurrentVideoHeight,
    PlaybackRequest? CurrentRequest)
{
    /// <summary>
    /// Default/empty state used as the initial value before any media is loaded.
    /// </summary>
    public static readonly PlayerState Empty = new(
        Mode: PlaybackMode.Live,
        IsPlaying: false,
        IsBuffering: false,
        IsMuted: false,
        Volume: 1.0f,
        Rate: 1.0f,
        Position: TimeSpan.Zero,
        Duration: TimeSpan.Zero,
        IsLive: false,
        Timeshift: null,
        IsAudioOnly: false,
        ErrorMessage: null,
        AudioTracks: [],
        SubtitleTracks: [],
        CurrentVideoWidth: null,
        CurrentVideoHeight: null,
        CurrentRequest: null);
}
