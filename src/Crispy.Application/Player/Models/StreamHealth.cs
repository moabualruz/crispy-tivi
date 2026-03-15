namespace Crispy.Application.Player.Models;

/// <summary>
/// Aggregated stream health metrics keyed by URL hash (PLR-40).
/// Used by the health score formula (PLR-38) and failover ranking (PLR-39).
/// </summary>
public class StreamHealth
{
    /// <summary>SHA-256(streamUrl)[0..8] hex — matches WatchHistoryEntry.Id key scheme.</summary>
    public required string UrlHash { get; set; }

    /// <summary>Total number of stall events recorded.</summary>
    public int StallCount { get; set; }

    /// <summary>Sum of all buffering durations in milliseconds.</summary>
    public long BufferSum { get; set; }

    /// <summary>Number of buffering duration samples recorded (for averaging).</summary>
    public int BufferSamples { get; set; }

    /// <summary>Time-to-first-frame from the most recent playback session (ms).</summary>
    public long TtffMs { get; set; }

    /// <summary>UTC timestamp of the last health metric update.</summary>
    public DateTimeOffset LastSeen { get; set; }
}
