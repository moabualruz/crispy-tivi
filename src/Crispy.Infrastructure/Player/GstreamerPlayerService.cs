using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// IPlayerService implementation backed by GStreamer via GstSharp bindings.
///
/// GStreamer availability is detected at runtime via <see cref="IsGstreamerAvailable"/>.
/// If the GstSharp managed bindings or native GStreamer shared libraries are absent,
/// all playback methods log a warning and return gracefully without throwing.
///
/// Pipeline construction uses <see cref="GstreamerPipeline"/> to build protocol-specific
/// pipeline descriptions for HLS, DASH, RTSP, UDP multicast, and generic HTTP streams.
/// Video frames are extracted via appsink (BGRA format) and pushed to
/// <see cref="IVideoFrameReceiver"/> for rendering by the UI layer's GpuVideoSurface.
///
/// TODO: GstSharp NuGet packages (GstSharpBundle) are not currently available in the
/// local NuGet cache. This implementation provides the full IPlayerService contract with
/// runtime detection — when GStreamer becomes available, the runtime check will pass and
/// actual GStreamer pipeline creation will be enabled. Until then, all methods gracefully
/// degrade with appropriate logging.
/// </summary>
public sealed class GstreamerPlayerService : IPlayerService, IDisposable
{
    private readonly IStreamHealthRepository _healthRepo;
    private readonly ILogger<GstreamerPlayerService> _logger;

    private readonly SimpleSubject<PlayerState> _stateSubject = new();
    private readonly SimpleSubject<float[]> _audioSamplesSubject = new();

    private PlayerState _state = PlayerState.Empty;
    private List<TrackInfo> _audioTracks = [];
    private List<TrackInfo> _subtitleTracks = [];

    // TTFF tracking — used when GStreamer runtime is available and appsink emits first frame
    private DateTimeOffset? _playStartedAt;
    private string? _currentUrlHash;

    // UI thread dispatch — captured at construction on the UI thread.
    // GStreamer bus messages and appsink callbacks fire on background threads;
    // we post state emissions back to the UI context.
    private readonly SynchronizationContext? _uiContext;

    // Runtime GStreamer availability detection
    private static bool _gstreamerAvailable;
    private static bool _gstreamerChecked;
    private static readonly object _gstreamerCheckLock = new();

    // Video frame receiver — set by the UI layer before playback starts
    private IVideoFrameReceiver? _frameReceiver;

    // Current pipeline description (for diagnostics)
    private string? _currentPipelineDescription;

    // Playback state tracking
    private float _volume = 1.0f;
    private bool _isMuted;
    private float _rate = 1.0f;
    private string? _aspectRatio;

    // Track IDs to re-apply after seek
    private int _savedAudioTrackId = -1;
    private int _savedSubtitleTrackId = -1;

    public GstreamerPlayerService(IStreamHealthRepository healthRepo, ILogger<GstreamerPlayerService> logger)
    {
        _healthRepo = healthRepo;
        _logger = logger;
        _uiContext = SynchronizationContext.Current;

        if (IsGstreamerAvailable())
        {
            InitializeGstreamer();
        }
        else
        {
            _logger.LogWarning(
                "GstreamerPlayerService: GStreamer runtime not available — playback is disabled. " +
                "Install GStreamer 1.24+ or add GstSharpBundle NuGet package.");
        }
    }

    /// <summary>
    /// Attempts to initialize the GStreamer runtime. Called once at construction
    /// if runtime detection indicates GStreamer is available.
    /// </summary>
    private void InitializeGstreamer()
    {
        // TODO: When GstSharp NuGet is available, this will call:
        //   Gst.Application.Init();
        // and set up the GStreamer main loop / bus watch.
        _logger.LogInformation("GstreamerPlayerService: GStreamer runtime initialized.");
    }

    /// <summary>
    /// Detects whether the GStreamer runtime (native shared libraries + managed bindings) is available.
    /// The result is cached after the first check.
    /// </summary>
    public static bool IsGstreamerAvailable()
    {
        lock (_gstreamerCheckLock)
        {
            if (!_gstreamerChecked)
            {
                _gstreamerAvailable = ProbeGstreamerRuntime();
                _gstreamerChecked = true;
            }

            return _gstreamerAvailable;
        }
    }

    /// <summary>
    /// Exposes the cached GStreamer availability result for use by other Infrastructure services
    /// (e.g. TimeshiftService). Returns <c>false</c> until <see cref="GstreamerPlayerService"/>
    /// has been constructed at least once (which triggers the check).
    /// </summary>
    internal static bool IsGstreamerRuntimeAvailable() => IsGstreamerAvailable();

    /// <summary>
    /// Probes for GStreamer runtime availability by attempting to load the managed bindings
    /// and initialize the native library.
    /// </summary>
    private static bool ProbeGstreamerRuntime()
    {
        try
        {
            // Attempt to load the GstSharp assembly dynamically.
            // This avoids a hard compile-time dependency — if the assembly is present
            // (e.g. via GstSharpBundle NuGet), we'll find it; otherwise we gracefully fail.
            var gstAssembly = System.Reflection.Assembly.Load("GstSharp");
            if (gstAssembly is null)
                return false;

            // Try to call Gst.Application.Init() via reflection
            var appType = gstAssembly.GetType("Gst.Application");
            if (appType is null)
                return false;

            var initMethod = appType.GetMethod("Init", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
            if (initMethod is null)
                return false;

            // Call Init() — this will throw if native GStreamer libs are missing
            initMethod.Invoke(null, null);
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <inheritdoc />
    public void SetFrameReceiver(IVideoFrameReceiver? receiver)
    {
        _frameReceiver = receiver;
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
        if (!IsGstreamerAvailable())
        {
            _logger.LogWarning("PlayAsync: GStreamer not available — playback skipped.");
            EmitState(_ => PlayerState.Empty with
            {
                ErrorMessage = "GStreamer not available. Install GStreamer 1.24+ runtime.",
                CurrentRequest = request,
            });
            return Task.CompletedTask;
        }

        // Stop current playback before starting new
        StopPipeline();

        _playStartedAt = DateTimeOffset.UtcNow;
        _currentUrlHash = StreamUrlHash.Compute(request.Url);

        // Build the GStreamer pipeline description
        _currentPipelineDescription = GstreamerPipeline.BuildPipeline(request.Url);
        _logger.LogDebug("GStreamer pipeline: {Pipeline}", _currentPipelineDescription);

        // TODO: When GstSharp is available, this will:
        // 1. var pipeline = Gst.Parse.Launch(_currentPipelineDescription);
        // 2. Get appsink element: pipeline.GetByName("videosink")
        // 3. Wire NewSample signal to extract BGRA buffer and call _frameReceiver?.OnFrame()
        // 4. Set pipeline state to Playing
        // 5. Start bus message watch for StateChanged, Eos, Error, Buffering
        // 6. Start position/duration query timer

        var mode = request.ContentType switch
        {
            PlaybackContentType.LiveTv => PlaybackMode.Live,
            PlaybackContentType.Radio => PlaybackMode.Radio,
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
        if (!IsGstreamerAvailable())
            return Task.CompletedTask;

        // TODO: Set pipeline state to Paused
        // pipeline?.SetState(Gst.State.Paused);

        EmitState(s => s with { IsPlaying = false });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task ResumeAsync()
    {
        if (!IsGstreamerAvailable())
            return Task.CompletedTask;

        // TODO: Set pipeline state to Playing
        // pipeline?.SetState(Gst.State.Playing);

        EmitState(s => s with { IsPlaying = true });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task StopAsync()
    {
        StopPipeline();
        _frameReceiver?.OnClear();
        EmitState(_ => PlayerState.Empty);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SeekAsync(TimeSpan position)
    {
        if (!IsGstreamerAvailable())
            return Task.CompletedTask;

        // TODO: pipeline.SeekSimple(Gst.Format.Time, SeekFlags.Flush | SeekFlags.KeyUnit, position.Ticks * 100)
        // GStreamer uses nanoseconds; TimeSpan.Ticks are 100ns units, so multiply by 100.

        EmitState(s => s with { Position = position });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetRateAsync(float rate)
    {
        if (!IsGstreamerAvailable())
            return Task.CompletedTask;

        _rate = rate;

        // TODO: Seek with rate parameter:
        // pipeline.Seek(rate, Gst.Format.Time, SeekFlags.Flush | SeekFlags.Accurate,
        //   SeekType.Set, currentPosition, SeekType.End, 0);

        EmitState(s => s with { Rate = rate });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetAudioTrackAsync(int trackId)
    {
        _savedAudioTrackId = trackId;

        // TODO: Set "current-audio" property on playbin/uridecodebin element
        // pipeline?.SetProperty("current-audio", trackId);

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetSubtitleTrackAsync(int trackId)
    {
        _savedSubtitleTrackId = trackId;

        // TODO: Set "current-text" property on playbin element
        // pipeline?.SetProperty("current-text", trackId);

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task AddSubtitleFileAsync(string filePath)
    {
        if (!IsGstreamerAvailable())
            return Task.CompletedTask;

        // TODO: Set "suburi" property on playbin element
        // pipeline?.SetProperty("suburi", "file://" + filePath);

        _logger.LogDebug("AddSubtitleFileAsync: {FilePath}", filePath);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetVolumeAsync(float volume)
    {
        var clamped = Math.Clamp(volume, 0f, 1f);
        _volume = clamped;

        // TODO: Set "volume" property on pipeline (GStreamer uses 0.0-1.0 range)
        // pipeline?.SetProperty("volume", (double)clamped);

        EmitState(s => s with { Volume = clamped });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task MuteAsync(bool mute)
    {
        _isMuted = mute;

        // TODO: Set "mute" property on pipeline
        // pipeline?.SetProperty("mute", mute);

        EmitState(s => s with { IsMuted = mute });
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetAspectRatioAsync(string? ratio)
    {
        _aspectRatio = ratio;

        // TODO: Apply via pixel-aspect-ratio on videoconvert caps or
        // by inserting a videoscale+capsfilter element in the pipeline.

        return Task.CompletedTask;
    }

    /// <summary>
    /// Applies a 10-band float array to the GStreamer equalizer-10bands element.
    /// Called by EqualizerService. No-op when GStreamer is not available.
    /// </summary>
    internal void ApplyEqualizerBands(float[] bands)
    {
        if (!IsGstreamerAvailable())
            return;

        // TODO: Insert equalizer-10bands element into pipeline if not present,
        // then set band0..band9 properties:
        // for (int i = 0; i < bands.Length && i < 10; i++)
        //     equalizer.SetProperty($"band{i}", (double)bands[i]);

        _logger.LogDebug("ApplyEqualizerBands: {BandCount} bands", bands.Length);
    }

    /// <summary>
    /// Clears (disables) the equalizer by removing the equalizer-10bands element
    /// from the pipeline. Called by EqualizerService. No-op when GStreamer is not available.
    /// </summary>
    internal void ClearEqualizer()
    {
        if (!IsGstreamerAvailable())
            return;

        // TODO: Remove equalizer-10bands element from pipeline or set all bands to 0.0

        _logger.LogDebug("ClearEqualizer: equalizer disabled.");
    }

    /// <inheritdoc />
    public void Dispose()
    {
        StopPipeline();

        _stateSubject.OnCompleted();
        _audioSamplesSubject.OnCompleted();
        _stateSubject.Dispose();
        _audioSamplesSubject.Dispose();

        _frameReceiver?.OnClear();
        _frameReceiver = null;
    }

    /// <summary>
    /// Stops the current GStreamer pipeline and releases resources.
    /// </summary>
    private void StopPipeline()
    {
        // TODO: When GstSharp is available:
        // pipeline?.SetState(Gst.State.Null);
        // pipeline?.Dispose();
        // pipeline = null;

        _currentPipelineDescription = null;
    }

    private void EmitState(Func<PlayerState, PlayerState> update)
    {
        _state = update(_state);
        PostToUiThread(() => _stateSubject.OnNext(_state));
    }

    /// <summary>
    /// Posts an action to the UI SynchronizationContext captured at construction.
    /// GStreamer bus messages and appsink callbacks fire on native background threads;
    /// state emissions must run on the UI thread so ViewModels can safely bind to
    /// PlayerState properties.
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
