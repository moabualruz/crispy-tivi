using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of the channel repository.
/// </summary>
public sealed class ChannelRepository : IChannelRepository
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    /// <summary>Creates a new ChannelRepository.</summary>
    public ChannelRepository(IDbContextFactory<AppDbContext> factory)
    {
        _factory = factory;
    }

    /// <inheritdoc />
    public async Task<Channel?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Channels
            .AsNoTracking()
            .Include(c => c.StreamEndpoints)
            .FirstOrDefaultAsync(c => c.Id == id, ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Channel>> GetBySourceAsync(int sourceId, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Channels
            .AsNoTracking()
            .Where(c => c.SourceId == sourceId)
            .Include(c => c.StreamEndpoints)
            .OrderBy(c => c.TvgChno ?? int.MaxValue)
            .ThenBy(c => c.Title)
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<int> UpsertRangeAsync(IEnumerable<Channel> channels, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var channelList = channels.ToList();
        if (channelList.Count == 0)
            return 0;

        // Batch-load all existing channels for the source(s) in one query.
        var sourceIds = channelList.Select(c => c.SourceId).Distinct().ToList();
        var existingChannels = await ctx.Channels
            .Where(c => sourceIds.Contains(c.SourceId))
            .ToListAsync(ct)
            .ConfigureAwait(false);

        // Build lookup dictionaries: one by TvgId, one by Title (for channels without TvgId).
        var byTvgId = existingChannels
            .Where(c => c.TvgId is not null)
            .ToDictionary(c => (c.SourceId, TvgId: c.TvgId!.ToUpperInvariant()));
        var byTitle = existingChannels
            .Where(c => c.TvgId is null)
            .GroupBy(c => (c.SourceId, c.Title))
            .ToDictionary(g => g.Key, g => g.First());

        int count = 0;
        foreach (var ch in channelList)
        {
            Channel? existing = null;
            if (ch.TvgId is not null)
                byTvgId.TryGetValue((ch.SourceId, ch.TvgId?.ToUpperInvariant() ?? ""), out existing);
            else
                byTitle.TryGetValue((ch.SourceId, ch.Title), out existing);

            if (existing is null)
            {
                ctx.Channels.Add(ch);
            }
            else
            {
                existing.Title = ch.Title;
                existing.TvgName = ch.TvgName;
                existing.TvgLogo = ch.TvgLogo;
                existing.GroupName = ch.GroupName;
                existing.MissedSyncCount = 0;
                // Preserve user fields: IsFavorite, IsHidden, CustomSortOrder, UserAssignedNumber
            }
            count++;
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return count;
    }

    /// <inheritdoc />
    public async Task IncrementMissedSyncAsync(
        int sourceId,
        IEnumerable<string> presentTvgIds,
        CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var presentSet = presentTvgIds.ToHashSet(StringComparer.OrdinalIgnoreCase);

        var absent = await ctx.Channels
            .Where(c => c.SourceId == sourceId && c.TvgId != null && !presentSet.Contains(c.TvgId!))
            .ToListAsync(ct)
            .ConfigureAwait(false);

        foreach (var ch in absent)
            ch.MissedSyncCount++;

        if (absent.Count > 0)
            await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task SoftRemoveExpiredAsync(int sourceId, int threshold, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);

        var expired = await ctx.Channels
            .Where(c => c.SourceId == sourceId && c.MissedSyncCount >= threshold)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        foreach (var ch in expired)
            ch.DeletedAt = DateTime.UtcNow;

        if (expired.Count > 0)
            await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }
}
