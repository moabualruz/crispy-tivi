using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// EF Core implementation of IMovieRepository backed by AppDbContext.
/// </summary>
public sealed class MovieRepository : IMovieRepository
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    /// <summary>Creates a new MovieRepository.</summary>
    public MovieRepository(IDbContextFactory<AppDbContext> factory)
    {
        _factory = factory;
    }

    /// <inheritdoc/>
    public async Task<Movie?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Movies
            .AsNoTracking()
            .FirstOrDefaultAsync(m => m.Id == id, ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<Movie>> GetBySourceAsync(int sourceId, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Movies
            .AsNoTracking()
            .Where(m => m.SourceId == sourceId)
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<Movie>> GetAllAsync(CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Movies
            .AsNoTracking()
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }

    /// <inheritdoc/>
    public async Task<int> UpsertRangeAsync(IEnumerable<Movie> movies, CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var movieList = movies.ToList();
        if (movieList.Count == 0)
            return 0;

        // Batch-load all existing movies for the source(s) in one query.
        var sourceIds = movieList.Select(m => m.SourceId).Distinct().ToList();
        var existingMovies = await ctx.Movies
            .Where(m => sourceIds.Contains(m.SourceId))
            .ToListAsync(ct)
            .ConfigureAwait(false);

        var byKey = new Dictionary<(int SourceId, string Title), Movie>();
        foreach (var em in existingMovies)
            byKey.TryAdd((em.SourceId, em.Title), em);

        var count = 0;
        foreach (var movie in movieList)
        {
            if (byKey.TryGetValue((movie.SourceId, movie.Title), out var existing))
            {
                existing.StreamUrl = movie.StreamUrl;
                existing.Overview = movie.Overview;
                existing.Year = movie.Year;
                existing.RuntimeMinutes = movie.RuntimeMinutes;
                existing.Thumbnail = movie.Thumbnail;
                if (movie.TmdbId.HasValue && !existing.TmdbId.HasValue)
                    existing.TmdbId = movie.TmdbId;
            }
            else
            {
                ctx.Movies.Add(movie);
                count++;
            }
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        return count;
    }
}
