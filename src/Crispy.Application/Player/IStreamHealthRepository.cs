namespace Crispy.Application.Player;

/// <summary>
/// Persists and queries per-stream health telemetry used for failover ranking (PLR-38/39).
/// Keyed by url_hash = first 8 bytes of SHA-256(streamUrl) in hex.
/// </summary>
public interface IStreamHealthRepository
{
    /// <summary>Records one stall event for the given stream.</summary>
    Task RecordStallAsync(string urlHash, CancellationToken ct = default);

    /// <summary>Records a buffer-underrun duration in milliseconds.</summary>
    Task RecordBufferDurationAsync(string urlHash, long durationMs, CancellationToken ct = default);

    /// <summary>Records time-to-first-frame in milliseconds.</summary>
    Task RecordTtffAsync(string urlHash, long ttffMs, CancellationToken ct = default);

    /// <summary>
    /// Computes the health score for a stream in [0.0, 1.0] where 1.0 is healthiest.
    /// Formula (PLR-38): see StreamHealthRepository for details.
    /// Returns 1.0 (unknown = assume healthy) when no data exists for the hash.
    /// </summary>
    Task<float> GetHealthScoreAsync(string urlHash, CancellationToken ct = default);

    /// <summary>
    /// Returns alternative <see cref="StreamEndpointDto"/> items for the given channel,
    /// ranked by (confidence * 0.6 + healthScore * 0.4) descending (PLR-39).
    /// Excludes endpoints belonging to <paramref name="excludeSourceId"/>.
    /// </summary>
    Task<IReadOnlyList<StreamEndpointDto>> GetRankedAlternativesAsync(
        int channelId,
        int excludeSourceId,
        CancellationToken ct = default);
}

/// <summary>
/// Lightweight projection of a stream endpoint returned by failover ranking.
/// </summary>
/// <param name="Url">Stream URL.</param>
/// <param name="SourceId">Source identifier.</param>
/// <param name="Priority">Original priority (lower = higher priority).</param>
/// <param name="FailoverScore">Composite failover score: confidence*0.6 + health*0.4.</param>
public sealed record StreamEndpointDto(
    string Url,
    int SourceId,
    int Priority,
    float FailoverScore);
