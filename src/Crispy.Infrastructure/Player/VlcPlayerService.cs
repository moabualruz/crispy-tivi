using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using Microsoft.Extensions.Logging;

#if LIBVLC
using LibVLCSharp.Shared;
#endif

namespace Crispy.Infrastructure.Player;

/// <summary>
/// IPlayerService implementation backed by LibVLCSharp (Desktop / Android / iOS).
/// On WASM the Browser project substitutes HtmlVideoPlayerService via DI instead.
///
/// When the LIBVLC compilation symbol is defined (set automatically when the
/// LibVLCSharp package is restored) the real VLC engine is used.
/// Without LIBVLC the service compiles as a no-op stub so the solution builds
/// even before packages are restored (matches the IHostedServiceShim pattern
/// used throughout Phase 2 — see STATE.md blocker note).
/// </summary>
public sealed class VlcPlayerService : IPlayerService, IDisposable
{
    private readonly IStreamHealthRepository _healthRepo;
    private readonly ILogger<VlcPlayerService> _logger;

    private readonly SimpleSubject<PlayerState> _stateSubject = new();
    private readonly SimpleSubject<float[]> _audioSamplesSubject = new();

    private PlayerState _state = PlayerState.Empty;
    private List<TrackInfo> _audioTracks = [];
    private List<TrackInfo> _subtitleTracks = [];

    // Fields used only inside #if LIBVLC blocks — suppress "unused field" warnings in stub build.
#pragma warning disable CS0169, CS0414, CS0649
    // Track IDs to re-apply after seek (fixes Pitfall 8 — subtitle IDs reset on seek)
    private int _savedAudioTrackId = -1;
    private int _savedSubtitleTrackId = -1;

    // TTFF tracking
    private DateTimeOffset? _playStartedAt;
    private string? _currentUrlHash;
    private bool _ttffRecorded;

    // Stall tracking (buffering after Playing)
    private bool _wasPlayingBeforeBuffer;
    private DateTimeOffset? _bufferStartedAt;
#pragma warning restore CS0169, CS0414, CS0649

    // UI thread dispatch — captured at construction on the UI thread.
    // VLC events fire on background threads; we post state emissions back to the UI context.
    private readonly SynchronizationContext? _uiContext;

#if LIBVLC
    private static bool _coreInitialized;
    private static readonly object _initLock = new();

    private readonly LibVLC _libVlc;
    private readonly LibVLCSharp.Shared.MediaPlayer _mediaPlayer;

    public VlcPlayerService(IStreamHealthRepository healthRepo, ILogger<VlcPlayerService> logger)
    {
        _healthRepo = healthRepo;
        _logger = logger;
        _uiContext = SynchronizationContext.Current;

        EnsureCoreInitialized();

        _libVlc = new LibVLC(enableDebugLogs: false);
        _mediaPlayer = new LibVLCSharp.Shared.MediaPlayer(_libVlc)
        {
            EnableHardwareDecoding = true,
        };

        WireEvents();
    }

    private static void EnsureCoreInitialized()
    {
        lock (_initLock)
        {
            if (_coreInitialized)
            {
                return;
            }

            Core.Initialize();
            _coreInitialized = true;
        }
    }

    private void WireEvents()
    {
        _mediaPlayer.Playing += (_, _) => PostToUiThread(() =>
        {
            // TTFF on first Playing event after PlayAsync
            if (!_ttffRecorded && _playStartedAt.HasValue && _currentUrlHash != null)
            {
                var ttff = (long)(DateTimeOffset.UtcNow - _playStartedAt.Value).TotalMilliseconds;
                _ = _healthRepo.RecordTtffAsync(_currentUrlHash, ttff);
                _ttffRecorded = true;
            }

            _wasPlayingBeforeBuffer = true;
            _audioTracks = BuildTrackList(_mediaPlayer.AudioTrackDescription, TrackKind.Audio);
            _subtitleTracks = BuildTrackList(_mediaPlayer.SpuDescription, TrackKind.Subtitle);

            EmitState(s => s with
            {
                IsPlaying = true,
                IsBuffering = false,
                AudioTracks = _audioTracks,
                SubtitleTracks = _subtitleTracks,
            });
        });

        _mediaPlayer.Paused += (_, _) => PostToUiThread(() =>
        {
            EmitState(s => s with { IsPlaying = false });
        });

        _mediaPlayer.Stopped += (_, _) => PostToUiThread(() =>
        {
            EmitState(s => s with { IsPlaying = false, IsBuffering = false });
        });

        _mediaPlayer.TimeChanged += (_, e) => PostToUiThread(() =>
        {
            EmitState(s => s with { Position = TimeSpan.FromMilliseconds(e.Time) });
        });

        _mediaPlayer.LengthChanged += (_, e) => PostToUiThread(() =>
        {
            EmitState(s => s with { Duration = TimeSpan.FromMilliseconds(e.Length) });
        });

        _mediaPlayer.Buffering += (_, e) => PostToUiThread(() =>
        {
            var isBuffering = e.Cache < 100f;

            if (isBuffering && _wasPlayingBeforeBuffer && _currentUrlHash != null)
            {
                _bufferStartedAt = DateTimeOffset.UtcNow;
                _ = _healthRepo.RecordStallAsync(_currentUrlHash);
            }
            else if (!isBuffering && _bufferStartedAt.HasValue && _currentUrlHash != null)
            {
                var durationMs = (long)(DateTimeOffset.UtcNow - _bufferStartedAt.Value).TotalMilliseconds;
                _ = _healthRepo.RecordBufferDurationAsync(_currentUrlHash, durationMs);
                _bufferStartedAt = null;
            }

            EmitState(s => s with { IsBuffering = isBuffering });
        });

        _mediaPlayer.EncounteredError += (_, _) => PostToUiThread(() =>
        {
            _logger.LogError("VLC encountered a playback error for {Url}", _state.CurrentRequest?.Url);
            EmitState(s => s with
            {
                IsPlaying = false,
                IsBuffering = false,
                ErrorMessage = "Playback error. The stream may be unavailable.",
            });
        });

        // ESAdded: re-apply saved track selections (Pitfall 8 fix)
        _mediaPlayer.ESAdded += (_, _) => PostToUiThread(() =>
        {
            _audioTracks = BuildTrackList(_mediaPlayer.AudioTrackDescription, TrackKind.Audio);
            _subtitleTracks = BuildTrackList(_mediaPlayer.SpuDescription, TrackKind.Subtitle);

            if (_savedAudioTrackId >= 0)
            {
                _mediaPlayer.SetAudioTrack(_savedAudioTrackId);
            }

            if (_savedSubtitleTrackId >= 0)
            {
                _mediaPlayer.SetSpu(_savedSubtitleTrackId);
            }

            EmitState(s => s with
            {
                AudioTracks = _audioTracks,
                SubtitleTracks = _subtitleTracks,
            });
        });

        // PCM audio callback for waveform visualizer
        _mediaPlayer.SetAudioCallbacks(
            play: (data, samples, count, pts) =>
            {
                // Interpret as float[] (FI32 format)
                unsafe
                {
                    var floatCount = (int)count;
                    var buffer = new float[floatCount];
                    var src = (float*)data;
                    for (var i = 0; i < floatCount; i++)
                    {
                        buffer[i] = src[i];
                    }

                    _audioSamplesSubject.OnNext(buffer);
                }
            },
            pause: (_, _) => { },
            resume: (_, _) => { },
            flush: _ => { },
            drain: _ => { });

        _mediaPlayer.SetAudioFormat("FI32", 44100, 2);
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
        _playStartedAt = DateTimeOffset.UtcNow;
        _ttffRecorded = false;
        _wasPlayingBeforeBuffer = false;
        _currentUrlHash = StreamUrlHash.Compute(request.Url);

        var media = new Media(_libVlc, new Uri(request.Url));

        if (request.HttpHeaders != null)
        {
            foreach (var (key, value) in request.HttpHeaders)
            {
                media.AddOption($":http-header={key}: {value}");
            }
        }

        if (!string.IsNullOrEmpty(request.UserAgent))
        {
            media.AddOption($":http-user-agent={request.UserAgent}");
        }

        _mediaPlayer.Media = media;
        media.Dispose();
        _mediaPlayer.Play();

        var mode = request.ContentType switch
        {
            Application.Player.Models.ContentType.LiveTv => PlaybackMode.Live,
            Application.Player.Models.ContentType.Radio => PlaybackMode.Radio,
            _ => PlaybackMode.Vod,
        };

        EmitState(s => s with
        {
            Mode = mode,
            IsPlaying = true,
            IsBuffering = true,
            ErrorMessage = null,
            CurrentRequest = request,
            AudioTracks = [],
            SubtitleTracks = [],
        });

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task PauseAsync()
    {
        _mediaPlayer.Pause();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task ResumeAsync()
    {
        _mediaPlayer.Play();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task StopAsync()
    {
        _mediaPlayer.Stop();
        EmitState(_ => PlayerState.Empty);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SeekAsync(TimeSpan position)
    {
        _mediaPlayer.Time = (long)position.TotalMilliseconds;
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetRateAsync(float rate)
    {
        // Live TV rate lock per PLR-07
        if (!_mediaPlayer.IsSeekable)
        {
            return Task.CompletedTask;
        }

        _mediaPlayer.SetRate(rate);
        EmitState(s => s with { Rate = rate });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetAudioTrackAsync(int trackId)
    {
        _savedAudioTrackId = trackId;
        _mediaPlayer.SetAudioTrack(trackId);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetSubtitleTrackAsync(int trackId)
    {
        _savedSubtitleTrackId = trackId;
        _mediaPlayer.SetSpu(trackId);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task AddSubtitleFileAsync(string filePath)
    {
        _mediaPlayer.AddSlave(MediaSlaveType.Subtitle, new Uri(filePath), enforce: true);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetVolumeAsync(float volume)
    {
        var clamped = Math.Clamp(volume, 0f, 1f);
        _mediaPlayer.Volume = (int)(clamped * 100);
        EmitState(s => s with { Volume = clamped });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task MuteAsync(bool mute)
    {
        _mediaPlayer.Mute = mute;
        EmitState(s => s with { IsMuted = mute });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetAspectRatioAsync(string? ratio)
    {
        if (ratio == null)
        {
            _mediaPlayer.AspectRatio = null;
        }
        else if (string.Equals(ratio, "Fill", StringComparison.OrdinalIgnoreCase))
        {
            _mediaPlayer.CropGeometry = "16:9";
        }
        else
        {
            _mediaPlayer.AspectRatio = ratio;
        }

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _stateSubject.OnCompleted();
        _audioSamplesSubject.OnCompleted();
        _stateSubject.Dispose();
        _audioSamplesSubject.Dispose();

        // IMPORTANT: MediaPlayer must be disposed BEFORE LibVLC (anti-pattern if reversed)
        _mediaPlayer.Dispose();
        _libVlc.Dispose();
    }

    private static List<TrackInfo> BuildTrackList(
        IEnumerable<LibVLCSharp.Shared.MediaTrack>? descs,
        TrackKind kind)
    {
        if (descs is null)
        {
            return [];
        }

        return descs
            .Select(d => new TrackInfo(
                Id: d.Id,
                Name: d.Description ?? d.Language ?? kind.ToString(),
                Language: d.Language ?? string.Empty,
                IsSelected: false,
                Kind: kind))
            .ToList();
    }

    private static List<TrackInfo> BuildTrackList(
        IEnumerable<LibVLCSharp.Shared.TrackDescription>? descs,
        TrackKind kind)
    {
        if (descs is null)
        {
            return [];
        }

        return descs
            .Where(d => d.Id >= 0)
            .Select(d => new TrackInfo(
                Id: d.Id,
                Name: d.Name ?? kind.ToString(),
                Language: string.Empty,
                IsSelected: false,
                Kind: kind))
            .ToList();
    }

#else

    // ── Stub (no-op) when LIBVLC symbol is not defined ────────────────────────
    // Allows the solution to compile with --no-restore while LibVLCSharp packages
    // are pending download (same pattern as IHostedServiceShim.cs in Phase 2).

    public VlcPlayerService(IStreamHealthRepository healthRepo, ILogger<VlcPlayerService> logger)
    {
        _healthRepo = healthRepo;
        _logger = logger;
        _uiContext = SynchronizationContext.Current;
        _logger.LogWarning(
            "VlcPlayerService running as NO-OP STUB — LIBVLC symbol not defined. " +
            "Add LibVLCSharp NuGet packages and define LIBVLC to enable real playback.");
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
        EmitState(_ => PlayerState.Empty with
        {
            ErrorMessage = "VLC not available (LibVLCSharp packages not installed).",
            CurrentRequest = request,
        });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task PauseAsync() => Task.CompletedTask;

    /// <inheritdoc />
    public Task ResumeAsync() => Task.CompletedTask;

    /// <inheritdoc />
    public Task StopAsync()
    {
        EmitState(_ => PlayerState.Empty);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SeekAsync(TimeSpan position) => Task.CompletedTask;

    /// <inheritdoc />
    public Task SetRateAsync(float rate) => Task.CompletedTask;

    /// <inheritdoc />
    public Task SetAudioTrackAsync(int trackId) => Task.CompletedTask;

    /// <inheritdoc />
    public Task SetSubtitleTrackAsync(int trackId) => Task.CompletedTask;

    /// <inheritdoc />
    public Task AddSubtitleFileAsync(string filePath) => Task.CompletedTask;

    /// <inheritdoc />
    public Task SetVolumeAsync(float volume) => Task.CompletedTask;

    /// <inheritdoc />
    public Task MuteAsync(bool mute) => Task.CompletedTask;

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

#endif

    private void EmitState(Func<PlayerState, PlayerState> update)
    {
        _state = update(_state);
        _stateSubject.OnNext(_state);
    }

    /// <summary>
    /// Posts an action to the UI SynchronizationContext captured at construction.
    /// VLC events fire on native background threads; state emissions must run on the UI thread
    /// so ViewModels can safely bind to PlayerState properties.
    /// Falls back to direct invocation if no UI context was captured (unit-test scenarios).
    /// </summary>
    private void PostToUiThread(Action action)
    {
        if (_uiContext != null)
        {
            _uiContext.Post(_ => action(), null);
        }
        else
        {
            action();
        }
    }

}
