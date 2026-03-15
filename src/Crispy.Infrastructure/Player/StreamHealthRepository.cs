using System.Collections.Concurrent;

using Crispy.Application.Player;
using Crispy.Domain.Interfaces;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// In-memory stream health repository (PLR-38/39).
/// Tracks stall count, buffer duration, and TTFF per stream URL hash.
/// Uses in-memory storage (acceptable for per-session health data — no persistence needed between app restarts).
///
/// Health score formula (PLR-38):
///   stallFactor   = clamp(stall_count / 10.0, 0, 1)
///   bufferFactor  = clamp(avg_buffer_ms / 10000.0, 0, 1)
///   ttffFactor    = clamp(ttff_ms / 10000.0, 0, 1)
///   rawScore      = 1.0 - (stallFactor*0.5 + bufferFactor*0.3 + ttffFactor*0.2)
///   decay         = exp(-deltaDays / 7.0)   (7-day exponential decay)
///   score         = 0.5 + (rawScore - 0.5) * decay   (decay toward neutral 0.5)
///
/// Failover ranking (PLR-39):
///   score = confidence * 0.6 + healthScore * 0.4
///   where confidence = 1.0 - clamp(failureCount / 5.0, 0, 1)
/// </summary>
public sealed class StreamHealthRepository : IStreamHealthRepository
{
    private readonly ConcurrentDictionary<string, HealthRecord> _records = new();
    private readonly IChannelRepository _channelRepo;

    public StreamHealthRepository(IChannelRepository channelRepo)
    {
        _channelRepo = channelRepo;
    }

    /// <inheritdoc />
    public Task RecordStallAsync(string urlHash, CancellationToken ct = default)
    {
        _records.AddOrUpdate(
            urlHash,
            _ => new HealthRecord { StallCount = 1, LastSeen = DateTimeOffset.UtcNow },
            (_, r) =>
            {
                r.StallCount++;
                r.LastSeen = DateTimeOffset.UtcNow;
                return r;
            });

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task RecordBufferDurationAsync(string urlHash, long durationMs, CancellationToken ct = default)
    {
        _records.AddOrUpdate(
            urlHash,
            _ => new HealthRecord
            {
                BufferSum = durationMs,
                BufferSamples = 1,
                LastSeen = DateTimeOffset.UtcNow,
            },
            (_, r) =>
            {
                r.BufferSum += durationMs;
                r.BufferSamples++;
                r.LastSeen = DateTimeOffset.UtcNow;
                return r;
            });

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task RecordTtffAsync(string urlHash, long ttffMs, CancellationToken ct = default)
    {
        _records.AddOrUpdate(
            urlHash,
            _ => new HealthRecord { TtffMs = ttffMs, LastSeen = DateTimeOffset.UtcNow },
            (_, r) =>
            {
                // Keep a rolling average of TTFF
                r.TtffMs = r.TtffMs == 0 ? ttffMs : (r.TtffMs + ttffMs) / 2;
                r.LastSeen = DateTimeOffset.UtcNow;
                return r;
            });

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task<float> GetHealthScoreAsync(string urlHash, CancellationToken ct = default)
    {
        if (!_records.TryGetValue(urlHash, out var record))
        {
            // No data — assume healthy
            return Task.FromResult(1.0f);
        }

        var score = ComputeHealthScore(record);
        return Task.FromResult(score);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<StreamEndpointDto>> GetRankedAlternativesAsync(
        int channelId,
        int excludeSourceId,
        CancellationToken ct = default)
    {
        var channel = await _channelRepo.GetByIdAsync(channelId, ct).ConfigureAwait(false);
        if (channel?.StreamEndpoints == null)
        {
            return [];
        }

        var results = new List<StreamEndpointDto>();

        foreach (var endpoint in channel.StreamEndpoints.Where(e => e.SourceId != excludeSourceId))
        {
            var urlHash = StreamUrlHash.Compute(endpoint.Url);
            var healthScore = await GetHealthScoreAsync(urlHash, ct).ConfigureAwait(false);

            // PLR-39: confidence = 1.0 - clamp(failureCount / 5.0, 0, 1)
            var confidence = 1.0f - Math.Clamp(endpoint.FailureCount / 5.0f, 0f, 1f);
            var failoverScore = confidence * 0.6f + healthScore * 0.4f;

            results.Add(new StreamEndpointDto(
                Url: endpoint.Url,
                SourceId: endpoint.SourceId,
                Priority: endpoint.Priority,
                FailoverScore: failoverScore));
        }

        return results.OrderByDescending(r => r.FailoverScore).ToList();
    }

    // PLR-38 health score formula
    private static float ComputeHealthScore(HealthRecord r)
    {
        var stallFactor = Math.Clamp(r.StallCount / 10.0f, 0f, 1f);

        var avgBufferMs = r.BufferSamples > 0 ? (float)r.BufferSum / r.BufferSamples : 0f;
        var bufferFactor = Math.Clamp(avgBufferMs / 10000.0f, 0f, 1f);

        var ttffFactor = Math.Clamp(r.TtffMs / 10000.0f, 0f, 1f);

        var rawScore = 1.0f - (stallFactor * 0.5f + bufferFactor * 0.3f + ttffFactor * 0.2f);

        // 7-day exponential decay toward neutral (0.5)
        var deltaDays = (DateTimeOffset.UtcNow - r.LastSeen).TotalDays;
        var decay = (float)Math.Exp(-deltaDays / 7.0);
        var score = 0.5f + (rawScore - 0.5f) * decay;

        return Math.Clamp(score, 0f, 1f);
    }

    private sealed class HealthRecord
    {
        public int StallCount { get; set; }
        public long BufferSum { get; set; }
        public int BufferSamples { get; set; }
        public long TtffMs { get; set; }
        public DateTimeOffset LastSeen { get; set; } = DateTimeOffset.UtcNow;
    }
}
