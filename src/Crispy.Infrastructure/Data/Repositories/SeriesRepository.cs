using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of ISeriesRepository backed by AppDbContext.
/// </summary>
public sealed class SeriesRepository : ISeriesRepository
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    /// <summary>Creates a new SeriesRepository.</summary>
    public SeriesRepository(IDbContextFactory<AppDbContext> factory)
    {
        _factory = factory;
    }

    /// <inheritdoc/>
    public async Task<Series?> GetByIdAsync(int id, bool includeEpisodes = false, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var query = ctx.SeriesItems.AsNoTracking().AsQueryable();
        if (includeEpisodes)
            query = query.Include(s => s.Episodes);
        return await query.FirstOrDefaultAsync(s => s.Id == id, ct).ConfigureAwait(false);
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<Series>> GetBySourceAsync(int sourceId, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.SeriesItems
            .AsNoTracking()
            .Where(s => s.SourceId == sourceId)
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc/>
    public async Task<int> UpsertRangeAsync(IEnumerable<Series> series, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var count = 0;

        foreach (var item in series)
        {
            var existing = await ctx.SeriesItems
                .FirstOrDefaultAsync(s => s.SourceId == item.SourceId && s.Title == item.Title, ct)
                .ConfigureAwait(false);

            if (existing is null)
            {
                ctx.SeriesItems.Add(item);
                count++;
            }
            else
            {
                existing.Overview = item.Overview;
                existing.Thumbnail = item.Thumbnail;
                if (item.TmdbId.HasValue && !existing.TmdbId.HasValue)
                    existing.TmdbId = item.TmdbId;
            }
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return count;
    }

    /// <inheritdoc/>
    public async Task<int> UpsertEpisodesAsync(IEnumerable<Episode> episodes, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var count = 0;

        foreach (var ep in episodes)
        {
            var existing = await ctx.Episodes
                .FirstOrDefaultAsync(e =>
                    e.SeriesId == ep.SeriesId &&
                    e.SeasonNumber == ep.SeasonNumber &&
                    e.EpisodeNumber == ep.EpisodeNumber, ct)
                .ConfigureAwait(false);

            if (existing is null)
            {
                ctx.Episodes.Add(ep);
                count++;
            }
            else
            {
                existing.StreamUrl = ep.StreamUrl;
                existing.Overview = ep.Overview;
                existing.RuntimeMinutes = ep.RuntimeMinutes;
                existing.Thumbnail = ep.Thumbnail;
            }
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return count;
    }
}
