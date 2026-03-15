using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of the sync history repository.
/// </summary>
public sealed class SyncHistoryRepository : ISyncHistoryRepository
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    /// <summary>Creates a new SyncHistoryRepository.</summary>
    public SyncHistoryRepository(IDbContextFactory<AppDbContext> factory)
    {
        _factory = factory;
    }

    /// <inheritdoc />
    public async Task<int> BeginSyncAsync(int sourceId, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);

        var record = new SyncHistory
        {
            SourceId = sourceId,
            StartedAt = DateTime.UtcNow,
            Status = SyncStatus.Running,
        };

        ctx.SyncHistory.Add(record);
        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return record.Id;
    }

    /// <inheritdoc />
    public async Task CompleteSyncAsync(
        int syncHistoryId,
        SyncStatus status,
        int channelCount,
        int vodCount,
        int epgCount,
        long durationMs,
        string? errorMessage = null,
        CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);

        var record = await ctx.SyncHistory.FindAsync([syncHistoryId], ct).ConfigureAwait(false);
        if (record is null)
            return;

        record.CompletedAt = DateTime.UtcNow;
        record.Status = status;
        record.ChannelCount = channelCount;
        record.VodCount = vodCount;
        record.EpgCount = epgCount;
        record.DurationMs = durationMs;
        record.ErrorMessage = errorMessage;

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<SyncHistory>> GetRecentAsync(
        int sourceId,
        int count = 10,
        CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.SyncHistory
            .Where(h => h.SourceId == sourceId)
            .OrderByDescending(h => h.StartedAt)
            .Take(count)
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }
}
