using System.Text.Json;
using System.Text.Json.Serialization;

using Crispy.Domain.Entities;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Sync;

/// <summary>
/// Enriches Movie and Series entities with metadata from The Movie Database (TMDB).
/// Rate-limited to at most 40 concurrent requests. Skips items that already have a TmdbId.
/// </summary>
public sealed class TmdbEnricher
{
    private readonly HttpClient _http;
    private readonly string _apiKey;
    private readonly ILogger<TmdbEnricher> _logger;
    private readonly SemaphoreSlim _rateLimiter = new(40, 40);

    private const string ImageBaseUrl = "https://image.tmdb.org/t/p/w500";
    private const int MaxCastMembers = 10;

    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    /// <summary>Creates a new TmdbEnricher.</summary>
    public TmdbEnricher(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<TmdbEnricher> logger)
    {
        _http = httpClient;
        _logger = logger;

        // API key priority: IConfiguration → bundled fallback
        _apiKey = configuration["Tmdb:ApiKey"]
                  ?? "BUNDLED_KEY_PLACEHOLDER";
    }

    // ─── Public API ───────────────────────────────────────────────────────────

    /// <summary>
    /// Enriches the provided movies with TMDB metadata.
    /// Movies that already have a TmdbId set are skipped.
    /// </summary>
    public async Task EnrichMoviesAsync(IReadOnlyList<Movie> movies, CancellationToken ct)
    {
        var tasks = movies
            .Where(m => m.TmdbId is null)
            .Select(m => EnrichMovieAsync(m, ct));

        await Task.WhenAll(tasks).ConfigureAwait(false);
    }

    /// <summary>
    /// Enriches the provided series with TMDB metadata.
    /// Series that already have a TmdbId set are skipped.
    /// </summary>
    public async Task EnrichSeriesAsync(IReadOnlyList<Series> series, CancellationToken ct)
    {
        var tasks = series
            .Where(s => s.TmdbId is null)
            .Select(s => EnrichSeriesItemAsync(s, ct));

        await Task.WhenAll(tasks).ConfigureAwait(false);
    }

    // ─── Movie enrichment ─────────────────────────────────────────────────────

    private async Task EnrichMovieAsync(Movie movie, CancellationToken ct)
    {
        await _rateLimiter.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            // Step 1: search by title + year
            var yearPart = movie.Year.HasValue ? $"&year={movie.Year}" : string.Empty;
            var searchUrl = $"/search/movie?query={Uri.EscapeDataString(movie.Title)}{yearPart}&api_key={_apiKey}";
            var searchResult = await GetWithRetryAsync<TmdbMovieSearchResponse>(searchUrl, ct).ConfigureAwait(false);

            if (searchResult?.Results is not { Count: > 0 } results)
            {
                _logger.LogDebug("TMDB: no match for movie '{Title}'", movie.Title);
                return;
            }

            var tmdbId = results[0].Id;

            // Step 2: get full details
            var detailUrl = $"/movie/{tmdbId}?append_to_response=credits&api_key={_apiKey}";
            var detail = await GetWithRetryAsync<TmdbMovieDetail>(detailUrl, ct).ConfigureAwait(false);

            if (detail is null)
                return;

            ApplyMovieDetail(movie, detail);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "TMDB enrichment failed for movie '{Title}'", movie.Title);
        }
        finally
        {
            _rateLimiter.Release();
        }
    }

    private static void ApplyMovieDetail(Movie movie, TmdbMovieDetail detail)
    {
        movie.TmdbId = detail.Id;
        movie.Overview = detail.Overview;
        movie.Year = detail.ReleaseDate?.Year;
        movie.Rating = detail.VoteAverage > 0 ? detail.VoteAverage : null;
        movie.RuntimeMinutes = detail.Runtime > 0 ? detail.Runtime : null;
        movie.Genres = detail.Genres is { Count: > 0 }
            ? string.Join(", ", detail.Genres.Select(g => g.Name))
            : null;
        movie.Thumbnail = detail.PosterPath is not null
            ? ImageBaseUrl + detail.PosterPath
            : null;
        movie.BackdropUrl = detail.BackdropPath is not null
            ? ImageBaseUrl + detail.BackdropPath
            : null;
    }

    // ─── Series enrichment ────────────────────────────────────────────────────

    private async Task EnrichSeriesItemAsync(Series series, CancellationToken ct)
    {
        await _rateLimiter.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            var searchUrl = $"/search/tv?query={Uri.EscapeDataString(series.Title)}&api_key={_apiKey}";
            var searchResult = await GetWithRetryAsync<TmdbTvSearchResponse>(searchUrl, ct).ConfigureAwait(false);

            if (searchResult?.Results is not { Count: > 0 } results)
            {
                _logger.LogDebug("TMDB: no match for series '{Title}'", series.Title);
                return;
            }

            var tmdbId = results[0].Id;

            var detailUrl = $"/tv/{tmdbId}?append_to_response=credits&api_key={_apiKey}";
            var detail = await GetWithRetryAsync<TmdbTvDetail>(detailUrl, ct).ConfigureAwait(false);

            if (detail is null)
                return;

            ApplySeriesDetail(series, detail);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "TMDB enrichment failed for series '{Title}'", series.Title);
        }
        finally
        {
            _rateLimiter.Release();
        }
    }

    private static void ApplySeriesDetail(Series series, TmdbTvDetail detail)
    {
        series.TmdbId = detail.Id;
        series.Overview = detail.Overview;
        series.FirstAiredYear = detail.FirstAirDate?.Year;
        series.Rating = detail.VoteAverage > 0 ? detail.VoteAverage : null;
        series.Genres = detail.Genres is { Count: > 0 }
            ? string.Join(", ", detail.Genres.Select(g => g.Name))
            : null;
        series.Thumbnail = detail.PosterPath is not null
            ? ImageBaseUrl + detail.PosterPath
            : null;
        series.BackdropUrl = detail.BackdropPath is not null
            ? ImageBaseUrl + detail.BackdropPath
            : null;
    }

    // ─── HTTP helper with Retry-After support ─────────────────────────────────

    private async Task<T?> GetWithRetryAsync<T>(string path, CancellationToken ct, int maxRetries = 3)
    {
        for (var attempt = 0; attempt <= maxRetries; attempt++)
        {
            var response = await _http.GetAsync(path, ct).ConfigureAwait(false);

            if (response.StatusCode == System.Net.HttpStatusCode.TooManyRequests)
            {
                var retryAfter = response.Headers.RetryAfter?.Delta ?? TimeSpan.FromSeconds(1);
                _logger.LogDebug("TMDB 429 rate limit — waiting {Seconds}s", retryAfter.TotalSeconds);
                await Task.Delay(retryAfter, ct).ConfigureAwait(false);
                continue;
            }

            response.EnsureSuccessStatusCode();
            await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
            return await JsonSerializer.DeserializeAsync<T>(stream, JsonOpts, ct).ConfigureAwait(false);
        }

        return default;
    }
}

// ─── TMDB DTOs ────────────────────────────────────────────────────────────────

internal sealed class TmdbMovieSearchResponse
{
    [JsonPropertyName("results")]
    public List<TmdbMovieSearchResult>? Results { get; set; }
}

internal sealed class TmdbMovieSearchResult
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;
}

internal sealed class TmdbMovieDetail
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("imdb_id")]
    public string? ImdbId { get; set; }

    [JsonPropertyName("overview")]
    public string? Overview { get; set; }

    [JsonPropertyName("release_date")]
    public DateOnly? ReleaseDate { get; set; }

    [JsonPropertyName("runtime")]
    public int? Runtime { get; set; }

    [JsonPropertyName("vote_average")]
    public double VoteAverage { get; set; }

    [JsonPropertyName("genres")]
    public List<TmdbGenre>? Genres { get; set; }

    [JsonPropertyName("poster_path")]
    public string? PosterPath { get; set; }

    [JsonPropertyName("backdrop_path")]
    public string? BackdropPath { get; set; }

    [JsonPropertyName("credits")]
    public TmdbCredits? Credits { get; set; }
}

internal sealed class TmdbTvSearchResponse
{
    [JsonPropertyName("results")]
    public List<TmdbTvSearchResult>? Results { get; set; }
}

internal sealed class TmdbTvSearchResult
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
}

internal sealed class TmdbTvDetail
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("overview")]
    public string? Overview { get; set; }

    [JsonPropertyName("first_air_date")]
    public DateOnly? FirstAirDate { get; set; }

    [JsonPropertyName("vote_average")]
    public double VoteAverage { get; set; }

    [JsonPropertyName("genres")]
    public List<TmdbGenre>? Genres { get; set; }

    [JsonPropertyName("poster_path")]
    public string? PosterPath { get; set; }

    [JsonPropertyName("backdrop_path")]
    public string? BackdropPath { get; set; }

    [JsonPropertyName("credits")]
    public TmdbCredits? Credits { get; set; }
}

internal sealed class TmdbGenre
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
}

internal sealed class TmdbCredits
{
    [JsonPropertyName("cast")]
    public List<TmdbCastMember>? Cast { get; set; }
}

internal sealed class TmdbCastMember
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("order")]
    public int Order { get; set; }
}
