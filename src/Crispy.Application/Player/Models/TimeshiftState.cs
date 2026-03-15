namespace Crispy.Application.Player.Models;

/// <summary>
/// Snapshot of the timeshift ring-buffer state — updated every second while buffering is active.
/// </summary>
/// <param name="BufferDuration">Total duration of content currently held in the ring buffer.</param>
/// <param name="Offset">
///   Current playback offset from the live edge — always zero or negative.
///   A value of -00:02:30 means "2 minutes 30 seconds behind live".
/// </param>
/// <param name="LiveEdgeTime">Wall-clock time of the live edge (approximately DateTimeOffset.UtcNow).</param>
/// <param name="OffsetDisplay">
///   Pre-formatted offset string for the OSD, e.g. "-2:30".
///   Empty string when at the live edge.
/// </param>
/// <param name="IsAtLiveEdge">True when the player is at (or within one segment of) the live edge.</param>
/// <param name="IsBufferFull">True when the ring buffer has reached its configured maximum duration.</param>
public sealed record TimeshiftState(
    TimeSpan BufferDuration,
    TimeSpan Offset,
    DateTimeOffset LiveEdgeTime,
    string OffsetDisplay,
    bool IsAtLiveEdge,
    bool IsBufferFull);
