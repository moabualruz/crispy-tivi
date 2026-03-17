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
    public async Task<IReadOnlyList<Series>> GetAllAsync(CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.SeriesItems
            .AsNoTracking()
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc/>
    public async Task<int> UpsertRangeAsync(IEnumerable<Series> series, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var seriesList = series.ToList();
        if (seriesList.Count == 0)
            return 0;

        // Batch-load all existing series for the source(s) in one query.
        var sourceIds = seriesList.Select(s => s.SourceId).Distinct().ToList();
        var existingSeries = await ctx.SeriesItems
            .Where(s => sourceIds.Contains(s.SourceId))
            .ToListAsync(ct)
            .ConfigureAwait(false);

        var byKey = new Dictionary<(int SourceId, string Title), Series>();
        foreach (var es in existingSeries)
            byKey.TryAdd((es.SourceId, es.Title), es);

        var count = 0;
        foreach (var item in seriesList)
        {
            if (byKey.TryGetValue((item.SourceId, item.Title), out var existing))
            {
                existing.Overview = item.Overview;
                existing.Thumbnail = item.Thumbnail;
                if (item.TmdbId.HasValue && !existing.TmdbId.HasValue)
                    existing.TmdbId = item.TmdbId;
            }
            else
            {
                ctx.SeriesItems.Add(item);
                count++;
            }
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return count;
    }

    /// <inheritdoc/>
    public async Task<int> UpsertEpisodesAsync(IEnumerable<Episode> episodes, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var episodeList = episodes.ToList();
        if (episodeList.Count == 0)
            return 0;

        // Batch-load all existing episodes for the referenced series in one query.
        var seriesIds = episodeList.Select(e => e.SeriesId).Distinct().ToList();
        var existingEpisodes = await ctx.Episodes
            .Where(e => seriesIds.Contains(e.SeriesId))
            .ToListAsync(ct)
            .ConfigureAwait(false);

        var byKey = new Dictionary<(int SeriesId, int Season, int Episode), Episode>();
        foreach (var ee in existingEpisodes)
            byKey.TryAdd((ee.SeriesId, ee.SeasonNumber, ee.EpisodeNumber), ee);

        var count = 0;
        foreach (var ep in episodeList)
        {
            if (byKey.TryGetValue((ep.SeriesId, ep.SeasonNumber, ep.EpisodeNumber), out var existing))
            {
                existing.StreamUrl = ep.StreamUrl;
                existing.Overview = ep.Overview;
                existing.RuntimeMinutes = ep.RuntimeMinutes;
                existing.Thumbnail = ep.Thumbnail;
            }
            else
            {
                ctx.Episodes.Add(ep);
                count++;
            }
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return count;
    }
}
