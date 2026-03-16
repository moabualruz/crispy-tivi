using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Platform-agnostic playback contract.
/// Implemented by Crispy.Infrastructure/Player/VlcPlayerService (Desktop/Android/iOS)
/// and by a future HTML5 fallback for WASM/WebOS.
/// </summary>
public interface IPlayerService
{
    /// <summary>Current playback state snapshot (always non-null; starts as PlayerState.Empty).</summary>
    PlayerState State { get; }

    /// <summary>Observable stream of state snapshots — emits every time any state field changes.</summary>
    IObservable<PlayerState> StateChanged { get; }

    /// <summary>Loads and begins playing the given request, replacing any current media.</summary>
    Task PlayAsync(PlaybackRequest request, CancellationToken ct = default);

    /// <summary>Pauses playback; no-op if already paused or stopped.</summary>
    Task PauseAsync();

    /// <summary>Resumes a paused session; no-op if already playing.</summary>
    Task ResumeAsync();

    /// <summary>Stops playback and releases media resources.</summary>
    Task StopAsync();

    /// <summary>Seeks to an absolute position (VOD / catch-up / timeshift).</summary>
    Task SeekAsync(TimeSpan position);

    /// <summary>Sets the playback speed multiplier (e.g. 0.5, 1.0, 1.5, 2.0).</summary>
    Task SetRateAsync(float rate);

    /// <summary>Activates the audio track with the given player-assigned id.</summary>
    Task SetAudioTrackAsync(int trackId);

    /// <summary>Activates the subtitle track with the given player-assigned id; -1 disables subtitles.</summary>
    Task SetSubtitleTrackAsync(int trackId);

    /// <summary>Loads an external subtitle file from the local filesystem.</summary>
    Task AddSubtitleFileAsync(string filePath);

    /// <summary>Sets the output volume; value is clamped to [0.0, 1.0] by the implementation.</summary>
    Task SetVolumeAsync(float volume);

    /// <summary>Mutes or unmutes audio output.</summary>
    Task MuteAsync(bool mute);

    /// <summary>
    /// Sets the video aspect ratio override (e.g. "16:9", "4:3").
    /// Pass <c>null</c> to restore the default Fit/Auto behaviour.
    /// </summary>
    Task SetAspectRatioAsync(string? ratio);

    /// <summary>Available audio tracks in the current media.</summary>
    IReadOnlyList<TrackInfo> AudioTracks { get; }

    /// <summary>Available subtitle tracks in the current media.</summary>
    IReadOnlyList<TrackInfo> SubtitleTracks { get; }

    /// <summary>
    /// Observable stream of PCM sample batches from the VLC audio filter.
    /// Used by the WaveformVisualizer control to render a live audio waveform for radio streams.
    /// Emits float[] containing interleaved samples at the media's native sample rate.
    /// </summary>
    IObservable<float[]> AudioSamples { get; }

    /// <summary>
    /// Returns the native player handle for the UI layer to bind to the video surface.
    /// For VLC: returns LibVLCSharp.Shared.MediaPlayer typed as object (keeps Application layer free of LibVLC dependency).
    /// For Browser: returns null (HTML5 video element is managed by JS interop).
    /// </summary>
    object? NativePlayerHandle { get; }
}
