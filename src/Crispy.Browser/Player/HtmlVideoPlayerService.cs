using System.Runtime.InteropServices.JavaScript;
using System.Runtime.Versioning;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using Microsoft.Extensions.Logging;

namespace Crispy.Browser.Player;

/// <summary>
/// IPlayerService implementation for the WASM/Browser target.
/// Delegates playback to a &lt;video&gt; element in the DOM via JS interop
/// using the System.Runtime.InteropServices.JavaScript API (available in net9.0-browser).
/// For HLS streams (.m3u8) the JS bridge uses hls.js (loaded from CDN in index.html).
///
/// Browser limitations (hard constraints — no workarounds):
///  - No timeshift (buffering is a no-op — TimeshiftService.StartBufferingAsync does nothing on browser)
///  - No background audio (browser tab must be active)
///  - PiP via video.requestPictureInPicture() only
///  - MPEG-TS / RTMP / RTSP / UDP → returns error PlayerState immediately
/// </summary>
[SupportedOSPlatform("browser")]
public sealed class HtmlVideoPlayerService : IPlayerService, IDisposable
{
    private const string UnsupportedSchemes = "rtmp rtsp udp mms";

    private readonly ILogger<HtmlVideoPlayerService> _logger;

    private readonly SimpleSubject<PlayerState> _stateSubject = new();
    private readonly SimpleSubject<float[]> _audioSamplesSubject = new();

    private PlayerState _state = PlayerState.Empty;
    private readonly List<TrackInfo> _audioTracks = [];
    private readonly List<TrackInfo> _subtitleTracks = [];

    // JS interop handle — created lazily
    private static bool _moduleLoaded;
    private static readonly Lock _moduleLock = new();

    public HtmlVideoPlayerService(ILogger<HtmlVideoPlayerService> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public PlayerState State => _state;

    /// <inheritdoc />
    public IObservable<PlayerState> StateChanged => _stateSubject;

    /// <inheritdoc />
    public IReadOnlyList<TrackInfo> AudioTracks => _audioTracks;

    /// <inheritdoc />
    public IReadOnlyList<TrackInfo> SubtitleTracks => _subtitleTracks;

    /// <inheritdoc />
    public IObservable<float[]> AudioSamples => _audioSamplesSubject;

    /// <inheritdoc />
    public Task PlayAsync(PlaybackRequest request, CancellationToken ct = default)
    {
        // Reject unsupported protocols
        if (Uri.TryCreate(request.Url, UriKind.Absolute, out var uri))
        {
            var scheme = uri.Scheme.ToLowerInvariant();
            if (UnsupportedSchemes.Contains(scheme, StringComparison.OrdinalIgnoreCase))
            {
                EmitState(s => s with
                {
                    IsPlaying = false,
                    ErrorMessage = $"Not supported in browser: {scheme.ToUpperInvariant()} streams cannot be played in WASM.",
                    CurrentRequest = request,
                });
                return Task.CompletedTask;
            }
        }

        try
        {
            CrispyPlayerInterop.Play(request.Url);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HtmlVideoPlayerService.PlayAsync failed for {Url}", request.Url);
            EmitState(s => s with
            {
                IsPlaying = false,
                ErrorMessage = ex.Message,
                CurrentRequest = request,
            });
            return Task.CompletedTask;
        }

        var mode = request.ContentType switch
        {
            PlaybackContentType.Radio => PlaybackMode.Radio,
            PlaybackContentType.LiveTv => PlaybackMode.Live,
            _ => PlaybackMode.Vod,
        };

        EmitState(s => s with
        {
            Mode = mode,
            IsPlaying = true,
            IsBuffering = true,
            ErrorMessage = null,
            CurrentRequest = request,
            IsLive = request.ContentType == PlaybackContentType.LiveTv || request.ContentType == PlaybackContentType.Radio,
        });

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task PauseAsync()
    {
        CrispyPlayerInterop.Pause();
        EmitState(s => s with { IsPlaying = false });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task ResumeAsync()
    {
        CrispyPlayerInterop.Resume();
        EmitState(s => s with { IsPlaying = true });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task StopAsync()
    {
        CrispyPlayerInterop.Stop();
        EmitState(_ => PlayerState.Empty);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SeekAsync(TimeSpan position)
    {
        CrispyPlayerInterop.Seek((long)position.TotalMilliseconds);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetRateAsync(float rate)
    {
        CrispyPlayerInterop.SetRate(rate);
        EmitState(s => s with { Rate = rate });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetAudioTrackAsync(int trackId) => Task.CompletedTask;

    /// <inheritdoc />
    public Task SetSubtitleTrackAsync(int trackId) => Task.CompletedTask;

    /// <inheritdoc />
    public Task AddSubtitleFileAsync(string filePath) => Task.CompletedTask;

    /// <inheritdoc />
    public Task SetVolumeAsync(float volume)
    {
        var clamped = Math.Clamp(volume, 0f, 1f);
        CrispyPlayerInterop.SetVolume(clamped);
        EmitState(s => s with { Volume = clamped });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task MuteAsync(bool mute)
    {
        CrispyPlayerInterop.SetMuted(mute);
        EmitState(s => s with { IsMuted = mute });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetAspectRatioAsync(string? ratio) => Task.CompletedTask;

    /// <inheritdoc />
    public void Dispose()
    {
        _stateSubject.OnCompleted();
        _audioSamplesSubject.OnCompleted();
        _stateSubject.Dispose();
        _audioSamplesSubject.Dispose();
    }

    private void EmitState(Func<PlayerState, PlayerState> update)
    {
        _state = update(_state);
        _stateSubject.OnNext(_state);
    }
}

/// <summary>
/// P/Invoke-style JS imports for the browser player (System.Runtime.InteropServices.JavaScript).
/// Maps to the exported functions in wwwroot/player.js.
/// </summary>
[SupportedOSPlatform("browser")]
internal static partial class CrispyPlayerInterop
{
    [JSImport("play", "player")]
    internal static partial void Play(string url);

    [JSImport("pause", "player")]
    internal static partial void Pause();

    [JSImport("resume", "player")]
    internal static partial void Resume();

    [JSImport("stop", "player")]
    internal static partial void Stop();

    [JSImport("seek", "player")]
    internal static partial void Seek(long positionMs);

    [JSImport("setRate", "player")]
    internal static partial void SetRate(float rate);

    [JSImport("setVolume", "player")]
    internal static partial void SetVolume(float volume);

    [JSImport("setMuted", "player")]
    internal static partial void SetMuted(bool muted);
}
