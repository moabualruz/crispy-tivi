using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using LibVLCSharp.Shared;
using LibVLCSharp.Shared.Structures;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// IPlayerService implementation backed by LibVLCSharp (Desktop / Android / iOS).
/// On WASM the Browser project substitutes HtmlVideoPlayerService via DI instead.
///
/// VLC availability is detected at runtime via <see cref="IsVlcAvailable"/>.
/// If the native libvlc shared library is absent (e.g. Browser / iOS), all
/// playback methods log a warning and return gracefully without throwing.
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

    // UI thread dispatch — captured at construction on the UI thread.
    // VLC events fire on background threads; we post state emissions back to the UI context.
    private readonly SynchronizationContext? _uiContext;

    // Runtime VLC availability detection
    private static bool _vlcAvailable;
    private static bool _vlcChecked;
    private static readonly object _vlcCheckLock = new();

    private static bool _coreInitialized;
    private static readonly object _initLock = new();

    private LibVLC? _libVlc;
    private MediaPlayer? _mediaPlayer;

    public VlcPlayerService(IStreamHealthRepository healthRepo, ILogger<VlcPlayerService> logger)
    {
        _healthRepo = healthRepo;
        _logger = logger;
        _uiContext = SynchronizationContext.Current;

        if (IsVlcAvailable())
        {
            _libVlc = new LibVLC(enableDebugLogs: false);
            _mediaPlayer = new MediaPlayer(_libVlc)
            {
                EnableHardwareDecoding = true,
            };

            WireEvents();
        }
        else
        {
            _logger.LogWarning(
                "VlcPlayerService: native libvlc not available on this platform — playback is disabled.");
        }
    }

    private static bool IsVlcAvailable()
    {
        lock (_vlcCheckLock)
        {
            if (!_vlcChecked)
            {
                try
                {
                    Core.Initialize();
                    _vlcAvailable = true;
                }
                catch
                {
                    _vlcAvailable = false;
                }

                _vlcChecked = true;
            }

            return _vlcAvailable;
        }
    }

    /// <summary>
    /// Exposes the cached VLC availability result for use by other Infrastructure services
    /// (e.g. TimeshiftService). Returns <c>false</c> until <see cref="VlcPlayerService"/>
    /// has been constructed at least once (which triggers the check).
    /// </summary>
    internal static bool IsVlcRuntimeAvailable() => IsVlcAvailable();

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
        _mediaPlayer!.Playing += (_, _) => PostToUiThread(() =>
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
            (data, samples, count, pts) =>
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
            (_, _) => { },
            (_, _) => { },
            (_, _) => { },
            _ => { });

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
        if (_mediaPlayer is null)
        {
            _logger.LogWarning("PlayAsync: VLC not available — playback skipped.");
            EmitState(_ => PlayerState.Empty with
            {
                ErrorMessage = "VLC not available on this platform.",
                CurrentRequest = request,
            });
            return Task.CompletedTask;
        }

        _playStartedAt = DateTimeOffset.UtcNow;
        _ttffRecorded = false;
        _wasPlayingBeforeBuffer = false;
        _currentUrlHash = StreamUrlHash.Compute(request.Url);

        var media = new Media(_libVlc!, new Uri(request.Url));

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
            Application.Player.Models.PlaybackContentType.LiveTv => PlaybackMode.Live,
            Application.Player.Models.PlaybackContentType.Radio => PlaybackMode.Radio,
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
        _mediaPlayer?.Pause();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task ResumeAsync()
    {
        _mediaPlayer?.Play();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task StopAsync()
    {
        _mediaPlayer?.Stop();
        EmitState(_ => PlayerState.Empty);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SeekAsync(TimeSpan position)
    {
        if (_mediaPlayer is not null)
            _mediaPlayer.Time = (long)position.TotalMilliseconds;
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetRateAsync(float rate)
    {
        if (_mediaPlayer is null)
            return Task.CompletedTask;

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
        _mediaPlayer?.SetAudioTrack(trackId);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetSubtitleTrackAsync(int trackId)
    {
        _savedSubtitleTrackId = trackId;
        _mediaPlayer?.SetSpu(trackId);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task AddSubtitleFileAsync(string filePath)
    {
        _mediaPlayer?.AddSlave(MediaSlaveType.Subtitle, filePath, true);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetVolumeAsync(float volume)
    {
        if (_mediaPlayer is not null)
        {
            var clamped = Math.Clamp(volume, 0f, 1f);
            _mediaPlayer.Volume = (int)(clamped * 100);
            EmitState(s => s with { Volume = clamped });
        }

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task MuteAsync(bool mute)
    {
        if (_mediaPlayer is not null)
        {
            _mediaPlayer.Mute = mute;
            EmitState(s => s with { IsMuted = mute });
        }

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetAspectRatioAsync(string? ratio)
    {
        if (_mediaPlayer is null)
            return Task.CompletedTask;

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

    // Owned equalizer instance — created lazily when EqualizerService first calls ApplyEqualizerBands.
    private Equalizer? _equalizer;

    /// <summary>
    /// Applies a 10-band float array to the underlying MediaPlayer equalizer.
    /// Called by EqualizerService. No-op when VLC is not available.
    /// </summary>
    internal void ApplyEqualizerBands(float[] bands)
    {
        if (_mediaPlayer is null)
        {
            return;
        }

        _equalizer ??= new Equalizer();

        for (var i = 0; i < bands.Length && i < 10; i++)
        {
            _equalizer.SetAmp(bands[i], (uint)i);
        }

        _mediaPlayer.SetEqualizer(_equalizer);
    }

    /// <summary>
    /// Clears (disables) the equalizer on the underlying MediaPlayer.
    /// Called by EqualizerService. No-op when VLC is not available.
    /// </summary>
    internal void ClearEqualizer()
    {
        if (_mediaPlayer is null)
        {
            return;
        }

        _equalizer?.Dispose();
        _equalizer = null;

        // LibVLCSharp 3.x lacks nullable annotation but the native API accepts null to disable.
#pragma warning disable CS8625
        _mediaPlayer.SetEqualizer(null);
#pragma warning restore CS8625
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _stateSubject.OnCompleted();
        _audioSamplesSubject.OnCompleted();
        _stateSubject.Dispose();
        _audioSamplesSubject.Dispose();

        _equalizer?.Dispose();
        _equalizer = null;

        if (_mediaPlayer is not null)
        {
            // IMPORTANT: MediaPlayer must be disposed BEFORE LibVLC (anti-pattern if reversed)
            _mediaPlayer.Dispose();
            _mediaPlayer = null;
        }

        _libVlc?.Dispose();
        _libVlc = null;
    }

    private static List<TrackInfo> BuildTrackList(
        IEnumerable<MediaTrack>? descs,
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
        IEnumerable<TrackDescription>? descs,
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
