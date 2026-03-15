using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of the EPG programme repository.
/// Operates on the dedicated epg.db via EpgDbContext.
/// </summary>
public sealed class EpgRepository : IEpgRepository
{
    private readonly IDbContextFactory<EpgDbContext> _factory;

    /// <summary>Creates a new EpgRepository.</summary>
    public EpgRepository(IDbContextFactory<EpgDbContext> factory)
    {
        _factory = factory;
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<EpgProgramme>> GetProgrammesAsync(
        string channelId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Programmes
            .Where(p => p.ChannelId == channelId && p.StopUtc >= fromUtc && p.StartUtc <= toUtc)
            .OrderBy(p => p.StartUtc)
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<EpgProgramme?> GetCurrentAsync(string channelId, DateTime atUtc, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Programmes
            .Where(p => p.ChannelId == channelId && p.StartUtc <= atUtc && p.StopUtc > atUtc)
            .FirstOrDefaultAsync(ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<int> UpsertRangeAsync(IEnumerable<EpgProgramme> programmes, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        int count = 0;

        foreach (var p in programmes)
        {
            var existing = await ctx.Programmes
                .FirstOrDefaultAsync(e =>
                    e.ChannelId == p.ChannelId &&
                    e.StartUtc == p.StartUtc, ct)
                .ConfigureAwait(false);

            if (existing is null)
            {
                ctx.Programmes.Add(p);
            }
            else
            {
                existing.Title = p.Title;
                existing.SubTitle = p.SubTitle;
                existing.Description = p.Description;
                existing.StopUtc = p.StopUtc;
                existing.Credits = p.Credits;
                existing.Rating = p.Rating;
            }
            count++;
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return count;
    }

    /// <inheritdoc />
    public async Task PurgeBeforeAsync(DateTime cutoffUtc, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);

        var old = await ctx.Programmes
            .Where(p => p.StopUtc < cutoffUtc)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        ctx.Programmes.RemoveRange(old);

        if (old.Count > 0)
            await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }
}
