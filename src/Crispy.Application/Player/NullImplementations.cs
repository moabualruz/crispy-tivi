using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// No-op ITimeshiftService for platforms where timeshift is not supported
/// (Browser/WASM — no local file system access for TS ring-buffer segments).
/// </summary>
public sealed class NullTimeshiftService : ITimeshiftService
{
    private static readonly TimeshiftState EmptyState = new(
        BufferDuration: TimeSpan.Zero,
        Offset: TimeSpan.Zero,
        LiveEdgeTime: DateTimeOffset.UtcNow,
        OffsetDisplay: string.Empty,
        IsAtLiveEdge: true,
        IsBufferFull: false);

    private readonly SimpleSubject<TimeshiftState> _subject = new();

    /// <inheritdoc />
    public TimeshiftState State => EmptyState;

    /// <inheritdoc />
    public IObservable<TimeshiftState> StateChanged => _subject;

    /// <inheritdoc />
    public TimeSpan MaxBufferDuration => TimeSpan.Zero;

    /// <inheritdoc />
    public long BufferFileSizeBytes => 0;

    /// <inheritdoc />
    public Task StartBufferingAsync(string liveUrl, CancellationToken ct = default) => Task.CompletedTask;

    /// <inheritdoc />
    public Task StopBufferingAsync() => Task.CompletedTask;

    /// <inheritdoc />
    public Task GoLiveAsync() => Task.CompletedTask;

    /// <inheritdoc />
    public Task SeekInBufferAsync(TimeSpan offset) => Task.CompletedTask;
}

/// <summary>
/// No-op IAudioStreamDetector — always returns false.
/// Used on platforms where track detection is unavailable before playback.
/// </summary>
public sealed class NullAudioStreamDetector : IAudioStreamDetector
{
    /// <inheritdoc />
    public bool IsAudioOnly(
        string? m3uAttributes,
        string? mimeType,
        IReadOnlyList<TrackInfo> tracks,
        string? groupTitle)
        => false;
}

/// <summary>
/// No-op IMediaSessionService — used on Desktop and Browser where OS
/// lock-screen controls are not applicable.
/// </summary>
public sealed class NullMediaSessionService : IMediaSessionService
{
    /// <inheritdoc />
    public Task UpdateNowPlayingAsync(
        string title,
        string? artist,
        string? artworkUrl,
        bool isPlaying)
        => Task.CompletedTask;

    /// <inheritdoc />
    public Task ClearAsync() => Task.CompletedTask;
}
