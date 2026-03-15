using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Ring-buffer timeshift contract.
/// The implementation records the live stream to a bounded circular file and allows
/// the player to seek backwards into the buffer while the live edge continues advancing.
/// </summary>
public interface ITimeshiftService
{
    /// <summary>Current timeshift ring-buffer state snapshot.</summary>
    TimeshiftState State { get; }

    /// <summary>Observable stream of state snapshots — emits every second while buffering is active.</summary>
    IObservable<TimeshiftState> StateChanged { get; }

    /// <summary>
    /// Starts recording the live stream into the ring buffer.
    /// The player continues at the live edge until the user seeks backwards.
    /// </summary>
    Task StartBufferingAsync(string liveUrl, CancellationToken ct = default);

    /// <summary>Stops recording and discards all buffered data.</summary>
    Task StopBufferingAsync();

    /// <summary>Resumes playback at the live edge, clearing any backwards offset.</summary>
    Task GoLiveAsync();

    /// <summary>
    /// Seeks to a position within the ring buffer relative to the live edge.
    /// <paramref name="offset"/> must be zero or negative (e.g. -00:02:30 = 2½ minutes behind live).
    /// </summary>
    Task SeekInBufferAsync(TimeSpan offset);

    /// <summary>Configured maximum ring-buffer duration (e.g. 4 hours).</summary>
    TimeSpan MaxBufferDuration { get; }

    /// <summary>Current size of the ring-buffer backing file on disk, in bytes.</summary>
    long BufferFileSizeBytes { get; }
}
