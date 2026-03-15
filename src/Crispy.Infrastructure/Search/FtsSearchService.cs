using System.Text;
using System.Text.RegularExpressions;

using Crispy.Application.Search;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Search;

/// <summary>
/// FTS5-backed search service. Executes raw SQLite FTS5 MATCH queries via AppDbContext.
/// Also provides autocomplete by mixing FTS5 prefix matches with search history.
/// </summary>
public sealed class FtsSearchService : ISearchService
{
    private readonly IDbContextFactory<AppDbContext> _appFactory;
    private readonly IDbContextFactory<EpgDbContext> _epgFactory;
    private readonly ILogger<FtsSearchService> _logger;

    private const int MaxResultsPerGroup = 10;
    private const int MaxAutocompleteResults = 8;
    private const int MaxSearchHistoryPerProfile = 50;

    // FTS5 special characters that need to be escaped
    private static readonly Regex FtsSpecialCharsRegex =
        new(@"[""*()^-]|\bNOT\b|\bAND\b|\bOR\b", RegexOptions.Compiled);

    /// <summary>Creates a new FtsSearchService.</summary>
    public FtsSearchService(
        IDbContextFactory<AppDbContext> appFactory,
        IDbContextFactory<EpgDbContext> epgFactory,
        ILogger<FtsSearchService> logger)
    {
        _appFactory = appFactory;
        _epgFactory = epgFactory;
        _logger = logger;
    }

    // ─── ISearchService ───────────────────────────────────────────────────────

    /// <inheritdoc/>
    public async Task<SearchResults> SearchAsync(string query, int profileId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(query))
            return new SearchResults();

        var sanitized = SanitizeFtsQuery(query);
        if (string.IsNullOrEmpty(sanitized))
            return new SearchResults();

        await using var ctx = await _appFactory.CreateDbContextAsync(ct).ConfigureAwait(false);

        // Execute FTS5 MATCH query — returns raw rows
        var rawRows = await ctx.Database
            .SqlQueryRaw<FtsRawRow>(
                "SELECT content_id AS ContentId, content_type AS ContentType, source_id AS SourceId, rank AS Rank FROM ContentSearch WHERE ContentSearch MATCH {0} ORDER BY rank LIMIT 50",
                sanitized)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        // Re-rank in C#: BM25 rank (negative in SQLite FTS5, lower = more relevant) * weights
        var channels = new List<SearchResultItem>();
        var movies = new List<SearchResultItem>();
        var series = new List<SearchResultItem>();

        foreach (var row in rawRows)
        {
            var weight = row.ContentType switch
            {
                "Channel" => 1.5,
                "Movie" => 1.0,
                "Series" => 1.0,
                "Episode" => 0.8,
                _ => 1.0,
            };

            // FTS5 rank is negative; negate to get positive relevance score
            var relevance = (-row.Rank) * weight;

            var item = new SearchResultItem
            {
                ContentId = row.ContentId,
                Title = string.Empty, // hydrated below
                Rank = relevance,
            };

            switch (row.ContentType)
            {
                case "Channel":
                    channels.Add(item);
                    break;
                case "Movie":
                    movies.Add(item);
                    break;
                case "Series" or "Episode":
                    series.Add(item);
                    break;
            }
        }

        // Hydrate titles from main tables
        await HydrateChannelTitlesAsync(ctx, channels, ct).ConfigureAwait(false);
        await HydrateMovieTitlesAsync(ctx, movies, ct).ConfigureAwait(false);
        await HydrateSeriesTitlesAsync(ctx, series, ct).ConfigureAwait(false);

        // Save search history (fire-and-forget style, don't fail search on history error)
        _ = Task.Run(() => SaveSearchHistoryAsync(ctx, profileId, query, ct), ct);

        return new SearchResults
        {
            Channels = channels.OrderByDescending(r => r.Rank).Take(MaxResultsPerGroup).ToList(),
            Movies = movies.OrderByDescending(r => r.Rank).Take(MaxResultsPerGroup).ToList(),
            Series = series.OrderByDescending(r => r.Rank).Take(MaxResultsPerGroup).ToList(),
        };
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<string>> AutocompleteAsync(string prefix, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(prefix) || prefix.Length < 1)
            return [];

        var sanitized = SanitizeFtsQuery(prefix);
        if (string.IsNullOrEmpty(sanitized))
            return [];

        await using var ctx = await _appFactory.CreateDbContextAsync(ct).ConfigureAwait(false);

        // FTS5 prefix match (sanitized already has trailing *)
        var ftsRows = await ctx.Database
            .SqlQueryRaw<FtsRawRow>(
                "SELECT content_id AS ContentId, content_type AS ContentType, source_id AS SourceId, rank AS Rank FROM ContentSearch WHERE ContentSearch MATCH {0} ORDER BY rank LIMIT 8",
                sanitized)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        var suggestions = new List<string>();

        // Hydrate titles for autocomplete
        var channelIds = ftsRows.Where(r => r.ContentType == "Channel").Select(r => r.ContentId).ToList();
        var movieIds = ftsRows.Where(r => r.ContentType == "Movie").Select(r => r.ContentId).ToList();
        var seriesIds = ftsRows.Where(r => r.ContentType is "Series" or "Episode").Select(r => r.ContentId).ToList();

        if (channelIds.Count > 0)
        {
            var titles = await ctx.Channels
                .Where(c => channelIds.Contains(c.Id))
                .Select(c => c.Title)
                .ToListAsync(ct)
                .ConfigureAwait(false);
            suggestions.AddRange(titles);
        }

        if (movieIds.Count > 0)
        {
            var titles = await ctx.Movies
                .Where(m => movieIds.Contains(m.Id))
                .Select(m => m.Title)
                .ToListAsync(ct)
                .ConfigureAwait(false);
            suggestions.AddRange(titles);
        }

        if (seriesIds.Count > 0)
        {
            var titles = await ctx.SeriesItems
                .Where(s => seriesIds.Contains(s.Id))
                .Select(s => s.Title)
                .ToListAsync(ct)
                .ConfigureAwait(false);
            suggestions.AddRange(titles);
        }

        return suggestions.Distinct().Take(MaxAutocompleteResults).ToList();
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /// <summary>Public wrapper for use by SearchRepository.</summary>
    public static string SanitizeFtsQueryPublic(string query) => SanitizeFtsQuery(query);

    /// <summary>Sanitizes a user query for FTS5 injection safety and appends prefix wildcard.</summary>
    private static string SanitizeFtsQuery(string query)
    {
        // Remove FTS5 special characters and boolean operators
        var sanitized = FtsSpecialCharsRegex.Replace(query.Trim(), " ");
        sanitized = sanitized.Trim();

        if (string.IsNullOrEmpty(sanitized))
            return string.Empty;

        // Wrap each word and append * to last word for prefix matching
        var words = sanitized.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (words.Length == 0)
            return string.Empty;

        var sb = new StringBuilder();
        for (var i = 0; i < words.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            sb.Append('"');
            sb.Append(words[i].Replace("\"", string.Empty));
            sb.Append('"');
            if (i == words.Length - 1)
                sb.Append('*');
        }

        return sb.ToString();
    }

    private static async Task HydrateChannelTitlesAsync(
        AppDbContext ctx,
        List<SearchResultItem> items,
        CancellationToken ct)
    {
        if (items.Count == 0) return;
        var ids = items.Select(i => i.ContentId).ToList();
        var map = await ctx.Channels
            .Where(c => ids.Contains(c.Id))
            .ToDictionaryAsync(c => c.Id, c => (c.Title, c.TvgLogo), ct)
            .ConfigureAwait(false);

        for (var i = 0; i < items.Count; i++)
        {
            if (map.TryGetValue(items[i].ContentId, out var info))
                items[i] = new SearchResultItem { ContentId = items[i].ContentId, Title = info.Title, Thumbnail = info.TvgLogo, Rank = items[i].Rank };
        }
    }

    private static async Task HydrateMovieTitlesAsync(
        AppDbContext ctx,
        List<SearchResultItem> items,
        CancellationToken ct)
    {
        if (items.Count == 0) return;
        var ids = items.Select(i => i.ContentId).ToList();
        var map = await ctx.Movies
            .Where(m => ids.Contains(m.Id))
            .ToDictionaryAsync(m => m.Id, m => (m.Title, m.Thumbnail), ct)
            .ConfigureAwait(false);

        for (var i = 0; i < items.Count; i++)
        {
            if (map.TryGetValue(items[i].ContentId, out var info))
                items[i] = new SearchResultItem { ContentId = items[i].ContentId, Title = info.Title, Thumbnail = info.Thumbnail, Rank = items[i].Rank };
        }
    }

    private static async Task HydrateSeriesTitlesAsync(
        AppDbContext ctx,
        List<SearchResultItem> items,
        CancellationToken ct)
    {
        if (items.Count == 0) return;
        var ids = items.Select(i => i.ContentId).ToList();
        var map = await ctx.SeriesItems
            .Where(s => ids.Contains(s.Id))
            .ToDictionaryAsync(s => s.Id, s => (s.Title, s.Thumbnail), ct)
            .ConfigureAwait(false);

        for (var i = 0; i < items.Count; i++)
        {
            if (map.TryGetValue(items[i].ContentId, out var info))
                items[i] = new SearchResultItem { ContentId = items[i].ContentId, Title = info.Title, Thumbnail = info.Thumbnail, Rank = items[i].Rank };
        }
    }

    private async Task SaveSearchHistoryAsync(AppDbContext ctx, int profileId, string query, CancellationToken ct)
    {
        try
        {
            // FIFO eviction: delete oldest if over limit
            await ctx.Database.ExecuteSqlRawAsync(
                """
                DELETE FROM SearchHistory WHERE Id IN (
                    SELECT Id FROM SearchHistory WHERE ProfileId = {0}
                    ORDER BY SearchedAt DESC LIMIT -1 OFFSET 49
                )
                """,
                profileId).ConfigureAwait(false);

            await ctx.Database.ExecuteSqlRawAsync(
                "INSERT INTO SearchHistory (ProfileId, Query, SearchedAt) VALUES ({0}, {1}, {2})",
                profileId, query, DateTime.UtcNow.ToString("O")).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Failed to save search history for profile {ProfileId}", profileId);
        }
    }
}

/// <summary>Keyless entity for FTS5 raw result rows.</summary>
internal sealed class FtsRawRow
{
    public int ContentId { get; set; }
    public string ContentType { get; set; } = string.Empty;
    public int SourceId { get; set; }
    public double Rank { get; set; }
}
