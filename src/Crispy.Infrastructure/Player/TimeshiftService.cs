using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Connectivity;

using Microsoft.Extensions.Logging;

#if LIBVLC
using LibVLCSharp.Shared;
#endif

namespace Crispy.Infrastructure.Player;

/// <summary>
/// ITimeshiftService implementation using segmented MPEG-TS files written by a
/// dedicated recorder MediaPlayer instance.
///
/// Two separate MediaPlayer instances are used:
/// - _recorderPlayer: writes segments via VLC :sout (recorder writes, never read from)
/// - _playbackPlayer: reads completed (N-1) segments for seek-back playback
///
/// This avoids Windows file-lock issues that arise from reading a file the recorder
/// is actively writing. Only completed segments (those whose write head has moved on)
/// are opened by the playback player.
///
/// When LIBVLC is not defined, the service compiles as a no-op stub.
/// </summary>
public sealed class TimeshiftService : ITimeshiftService, IDisposable
{
    private const int SegmentDurationSeconds = 60;

    private readonly IConnectivityMonitor _connectivity;
    private readonly ILogger<TimeshiftService> _logger;

    private readonly SimpleSubject<TimeshiftState> _stateSubject = new();
    private TimeshiftState _state = new(
        BufferDuration: TimeSpan.Zero,
        Offset: TimeSpan.Zero,
        LiveEdgeTime: DateTimeOffset.UtcNow,
        OffsetDisplay: string.Empty,
        IsAtLiveEdge: true,
        IsBufferFull: false);

#pragma warning disable CS0169, CS0414, CS0649
    private string? _bufferDir;
    private int _currentSegmentIndex;
    private readonly Dictionary<int, DateTimeOffset> _segmentStartTimes = [];
    private Timer? _tickTimer;
    private Timer? _segmentTimer;
#pragma warning restore CS0169, CS0414, CS0649

#if LIBVLC
    private LibVLC? _libVlc;
    private LibVLCSharp.Shared.MediaPlayer? _recorderPlayer;
    private LibVLCSharp.Shared.MediaPlayer? _playbackPlayer;
    private bool _isRecording;
#endif

    /// <inheritdoc />
    public TimeSpan MaxBufferDuration { get; } = TimeSpan.FromHours(4);

    /// <inheritdoc />
    public long BufferFileSizeBytes
    {
        get
        {
            if (_bufferDir == null || !Directory.Exists(_bufferDir))
            {
                return 0;
            }

            return new DirectoryInfo(_bufferDir)
                .GetFiles("seg_*.ts")
                .Sum(f => f.Length);
        }
    }

    /// <inheritdoc />
    public TimeshiftState State => _state;

    /// <inheritdoc />
    public IObservable<TimeshiftState> StateChanged => _stateSubject;

    public TimeshiftService(IConnectivityMonitor connectivity, ILogger<TimeshiftService> logger)
    {
        _connectivity = connectivity;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task StartBufferingAsync(string liveUrl, CancellationToken ct = default)
    {
        // Timeshift disabled on metered connections
        if (_connectivity.CurrentLevel != ConnectivityLevel.Online)
        {
            _logger.LogWarning("Timeshift skipped — connectivity is not Online.");
            return;
        }

#if LIBVLC
        await StopBufferingAsync().ConfigureAwait(false);

        _bufferDir = Path.Combine(Path.GetTempPath(), "CrispyTivi", "timeshift", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_bufferDir);

        _currentSegmentIndex = 0;
        _segmentStartTimes.Clear();

        _libVlc = new LibVLC(enableDebugLogs: false);
        _recorderPlayer = new LibVLCSharp.Shared.MediaPlayer(_libVlc);
        _playbackPlayer = new LibVLCSharp.Shared.MediaPlayer(_libVlc);

        StartNextSegment(liveUrl);

        // Tick every second to update state
        _tickTimer = new Timer(_ => OnTick(), null, TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(1));

        // Rotate to next segment every SegmentDurationSeconds
        _segmentTimer = new Timer(_ => RotateSegment(liveUrl), null,
            TimeSpan.FromSeconds(SegmentDurationSeconds),
            TimeSpan.FromSeconds(SegmentDurationSeconds));

        _isRecording = true;
        _logger.LogInformation("Timeshift recording started in {Dir}", _bufferDir);
#else
        await Task.CompletedTask.ConfigureAwait(false);
        _logger.LogWarning("TimeshiftService: LIBVLC not available — buffering is a no-op.");
#endif
    }

    /// <inheritdoc />
    public Task StopBufferingAsync()
    {
#if LIBVLC
        _tickTimer?.Dispose();
        _tickTimer = null;
        _segmentTimer?.Dispose();
        _segmentTimer = null;

        _recorderPlayer?.Stop();
        _recorderPlayer?.Dispose();
        _recorderPlayer = null;

        _playbackPlayer?.Stop();
        _playbackPlayer?.Dispose();
        _playbackPlayer = null;

        _libVlc?.Dispose();
        _libVlc = null;

        _isRecording = false;

        // Clean up temp files
        if (_bufferDir != null && Directory.Exists(_bufferDir))
        {
            try
            {
                Directory.Delete(_bufferDir, recursive: true);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to delete timeshift buffer dir {Dir}", _bufferDir);
            }
        }

        _bufferDir = null;
        _segmentStartTimes.Clear();
#endif
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task GoLiveAsync()
    {
#if LIBVLC
        _playbackPlayer?.Stop();
#endif
        _state = _state with
        {
            Offset = TimeSpan.Zero,
            OffsetDisplay = string.Empty,
            IsAtLiveEdge = true,
        };
        _stateSubject.OnNext(_state);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SeekInBufferAsync(TimeSpan offset)
    {
        if (offset > TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(offset), "Offset must be zero or negative.");
        }

#if LIBVLC
        if (_bufferDir == null || _recorderPlayer == null || _playbackPlayer == null)
        {
            return Task.CompletedTask;
        }

        var targetTime = DateTimeOffset.UtcNow + offset;

        // Find the segment whose start time is closest to targetTime
        var targetSegment = _segmentStartTimes
            .Where(kvp => kvp.Value <= targetTime)
            .OrderByDescending(kvp => kvp.Value)
            .Select(kvp => (int?)kvp.Key)
            .FirstOrDefault();

        if (targetSegment is null)
        {
            _logger.LogWarning("No segment found for offset {Offset}", offset);
            return Task.CompletedTask;
        }

        // Only open completed segments (not the one currently being written)
        var safeSegmentIndex = Math.Min(targetSegment.Value, _currentSegmentIndex - 1);
        if (safeSegmentIndex < 0)
        {
            return Task.CompletedTask;
        }

        var segmentPath = GetSegmentPath(safeSegmentIndex);
        if (!File.Exists(segmentPath))
        {
            _logger.LogWarning("Segment file not found: {Path}", segmentPath);
            return Task.CompletedTask;
        }

        var segmentStart = _segmentStartTimes[safeSegmentIndex];
        var seekWithinSegment = targetTime - segmentStart;

        using var media = new Media(_libVlc!, new Uri(segmentPath));
        _playbackPlayer.Media = media;
        _playbackPlayer.Play();

        if (seekWithinSegment.TotalMilliseconds > 500)
        {
            _playbackPlayer.Time = (long)seekWithinSegment.TotalMilliseconds;
        }
#endif
        _state = _state with
        {
            Offset = offset,
            OffsetDisplay = FormatOffset(offset),
            IsAtLiveEdge = false,
        };
        _stateSubject.OnNext(_state);

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _tickTimer?.Dispose();
        _segmentTimer?.Dispose();
        _stateSubject.OnCompleted();
        _stateSubject.Dispose();

#if LIBVLC
        _recorderPlayer?.Dispose();
        _playbackPlayer?.Dispose();
        _libVlc?.Dispose();
#endif

        if (_bufferDir != null && Directory.Exists(_bufferDir))
        {
            try
            {
                Directory.Delete(_bufferDir, recursive: true);
            }
            catch { /* best effort */ }
        }
    }

#if LIBVLC
    private void StartNextSegment(string liveUrl)
    {
        var segPath = GetSegmentPath(_currentSegmentIndex);
        _segmentStartTimes[_currentSegmentIndex] = DateTimeOffset.UtcNow;

        // VLC :sout writes raw TS to disk
        var soutOption = $":sout=#std{{access=file,mux=ts,dst={segPath}}}";
        using var media = new Media(_libVlc!, new Uri(liveUrl));
        media.AddOption(soutOption);
        media.AddOption(":sout-keep");
        _recorderPlayer!.Media = media;
        _recorderPlayer.Play();

        _logger.LogDebug("Timeshift: recording segment {Index} -> {Path}", _currentSegmentIndex, segPath);
    }

    private void RotateSegment(string liveUrl)
    {
        _recorderPlayer?.Stop();
        _currentSegmentIndex++;

        PurgeOldSegments();
        StartNextSegment(liveUrl);
    }

    private void PurgeOldSegments()
    {
        if (_bufferDir == null)
        {
            return;
        }

        var cutoff = DateTimeOffset.UtcNow - MaxBufferDuration;
        var toDelete = _segmentStartTimes
            .Where(kvp => kvp.Value < cutoff)
            .Select(kvp => kvp.Key)
            .ToList();

        foreach (var idx in toDelete)
        {
            _segmentStartTimes.Remove(idx);
            var path = GetSegmentPath(idx);
            try
            {
                File.Delete(path);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to delete old segment {Path}", path);
            }
        }
    }
#endif

    private void OnTick()
    {
        var bufferDuration = _segmentStartTimes.Count > 0
            ? TimeSpan.FromSeconds(_segmentStartTimes.Count * SegmentDurationSeconds)
            : TimeSpan.Zero;

        var isBufferFull = bufferDuration >= MaxBufferDuration;

#if LIBVLC
        var isAtLiveEdge = _playbackPlayer?.IsPlaying != true;
#else
        var isAtLiveEdge = true;
#endif

        _state = _state with
        {
            BufferDuration = bufferDuration,
            LiveEdgeTime = DateTimeOffset.UtcNow,
            IsAtLiveEdge = isAtLiveEdge,
            IsBufferFull = isBufferFull,
        };

        _stateSubject.OnNext(_state);
    }

    private string GetSegmentPath(int index) =>
        Path.Combine(_bufferDir!, $"seg_{index:D6}.ts");

    private static string FormatOffset(TimeSpan offset)
    {
        if (offset == TimeSpan.Zero)
        {
            return string.Empty;
        }

        var abs = offset.Duration();
        return abs.TotalHours >= 1
            ? $"-{(int)abs.TotalHours}:{abs.Minutes:D2}:{abs.Seconds:D2}"
            : $"-{abs.Minutes}:{abs.Seconds:D2}";
    }
}
