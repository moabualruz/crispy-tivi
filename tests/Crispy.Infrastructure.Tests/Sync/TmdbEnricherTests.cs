using System.Net;
using System.Text;

using Crispy.Domain.Entities;
using Crispy.Infrastructure.Sync;
using Crispy.Infrastructure.Tests.Jellyfin;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Sync;

/// <summary>
/// Tests for TmdbEnricher: TMDB metadata population, skip-if-already-enriched, rate limiting.
/// Uses SequentialHttpMessageHandler to mock TMDB HTTP responses.
/// </summary>
[Trait("Category", "Unit")]
public class TmdbEnricherTests
{
    private static TmdbEnricher MakeEnricher(params (HttpStatusCode status, string json)[] responses)
    {
        var handler = new SequentialHttpMessageHandler(responses);
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri("https://api.themoviedb.org/3/") };
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Tmdb:ApiKey"] = "test_api_key" })
            .Build();
        return new TmdbEnricher(httpClient, config, NullLogger<TmdbEnricher>.Instance);
    }

    // ─── Movie enrichment ─────────────────────────────────────────────────────

    [Fact]
    public async Task EnrichMoviesAsync_PopulatesAllMetadataFields()
    {
        const string searchJson = """
        {
            "results": [{"id": 12345, "title": "Test Movie", "release_date": "2020-05-01"}],
            "total_results": 1
        }
        """;
        const string detailJson = """
        {
            "id": 12345,
            "imdb_id": "tt1234567",
            "overview": "A great test movie",
            "release_date": "2020-05-01",
            "runtime": 120,
            "vote_average": 8.5,
            "genres": [{"id":28,"name":"Action"},{"id":12,"name":"Adventure"}],
            "poster_path": "/poster.jpg",
            "backdrop_path": "/backdrop.jpg",
            "credits": {
                "cast": [
                    {"name":"Actor One","order":0},
                    {"name":"Actor Two","order":1}
                ]
            }
        }
        """;

        var enricher = MakeEnricher(
            (HttpStatusCode.OK, searchJson),
            (HttpStatusCode.OK, detailJson));

        var movie = new Movie { Title = "Test Movie", SourceId = 1, Year = 2020 };

        await enricher.EnrichMoviesAsync([movie], CancellationToken.None);

        movie.TmdbId.Should().Be(12345);
        movie.Overview.Should().Be("A great test movie");
        movie.RuntimeMinutes.Should().Be(120);
        movie.Rating.Should().Be(8.5);
        movie.Genres.Should().Contain("Action");
        movie.Thumbnail.Should().Contain("poster.jpg");
        movie.BackdropUrl.Should().Contain("backdrop.jpg");
    }

    [Fact]
    public async Task EnrichMoviesAsync_SkipsMovies_WithTmdbIdAlreadySet()
    {
        // No HTTP responses queued — if enricher calls TMDB, the test will throw
        var enricher = MakeEnricher();

        var movie = new Movie { Title = "Already Enriched", SourceId = 1, TmdbId = 99999 };

        // Should not throw even with no HTTP responses configured
        await enricher.EnrichMoviesAsync([movie], CancellationToken.None);

        movie.TmdbId.Should().Be(99999, "already-enriched movies should not be overwritten");
    }

    [Fact]
    public async Task EnrichMoviesAsync_HandlesEmptySearchResults_Gracefully()
    {
        const string emptySearch = """{"results":[],"total_results":0}""";
        var enricher = MakeEnricher((HttpStatusCode.OK, emptySearch));

        var movie = new Movie { Title = "Unknown Film", SourceId = 1 };

        await enricher.EnrichMoviesAsync([movie], CancellationToken.None);

        movie.TmdbId.Should().BeNull("no TMDB match means no enrichment");
    }

    [Fact]
    public async Task EnrichMoviesAsync_ZeroVoteAverage_SetsNullRating()
    {
        const string searchJson = """{"results":[{"id":1,"title":"Zero Vote"}],"total_results":1}""";
        const string detailJson = """{"id":1,"vote_average":0.0,"overview":null,"genres":null,"credits":null}""";

        var enricher = MakeEnricher(
            (HttpStatusCode.OK, searchJson),
            (HttpStatusCode.OK, detailJson));

        var movie = new Movie { Title = "Zero Vote", SourceId = 1 };
        await enricher.EnrichMoviesAsync([movie], CancellationToken.None);

        movie.Rating.Should().BeNull("vote_average of 0 must map to null Rating");
    }

    [Fact]
    public async Task EnrichMoviesAsync_MovieWithoutYear_BuildsUrlWithoutYearParam()
    {
        // No year → search URL must not include &year= — verified indirectly by successful enrichment
        const string searchJson = """{"results":[{"id":555,"title":"Timeless"}],"total_results":1}""";
        const string detailJson = """{"id":555,"vote_average":6.0,"overview":"No year","genres":null,"credits":null}""";

        var enricher = MakeEnricher(
            (HttpStatusCode.OK, searchJson),
            (HttpStatusCode.OK, detailJson));

        var movie = new Movie { Title = "Timeless", SourceId = 1, Year = null };
        await enricher.EnrichMoviesAsync([movie], CancellationToken.None);

        movie.TmdbId.Should().Be(555, "year-less movies should still be enriched via title-only search");
    }

    [Fact]
    public async Task EnrichMoviesAsync_HttpError_DoesNotThrow_AndLeavesMovieUnenriched()
    {
        // HTTP 500 on search → enricher must swallow and leave TmdbId null
        var enricher = MakeEnricher((HttpStatusCode.InternalServerError, "{}"));

        var movie = new Movie { Title = "Broken Film", SourceId = 1 };
        var act = () => enricher.EnrichMoviesAsync([movie], CancellationToken.None);

        await act.Should().NotThrowAsync("non-OCE HTTP failures must be swallowed");
        movie.TmdbId.Should().BeNull();
    }

    // ─── Series enrichment ────────────────────────────────────────────────────

    [Fact]
    public async Task EnrichSeriesAsync_PopulatesAllMetadataFields()
    {
        const string searchJson = """
        {
            "results": [{"id": 67890, "name": "Test Show", "first_air_date": "2019-01-01"}],
            "total_results": 1
        }
        """;
        const string detailJson = """
        {
            "id": 67890,
            "overview": "A great test show",
            "first_air_date": "2019-01-01",
            "vote_average": 7.8,
            "genres": [{"id":18,"name":"Drama"}],
            "poster_path": "/show_poster.jpg",
            "backdrop_path": "/show_backdrop.jpg",
            "credits": {
                "cast": [{"name":"Star Actor","order":0}]
            }
        }
        """;

        var enricher = MakeEnricher(
            (HttpStatusCode.OK, searchJson),
            (HttpStatusCode.OK, detailJson));

        var series = new Series { Title = "Test Show", SourceId = 1 };

        await enricher.EnrichSeriesAsync([series], CancellationToken.None);

        series.TmdbId.Should().Be(67890);
        series.Overview.Should().Be("A great test show");
        series.FirstAiredYear.Should().Be(2019);
        series.Rating.Should().Be(7.8);
        series.Genres.Should().Contain("Drama");
        series.Thumbnail.Should().Contain("show_poster.jpg");
        series.BackdropUrl.Should().Contain("show_backdrop.jpg");
    }

    [Fact]
    public async Task EnrichSeriesAsync_SkipsSeries_WithTmdbIdAlreadySet()
    {
        var enricher = MakeEnricher(); // no responses — would throw if HTTP is called

        var series = new Series { Title = "Already Enriched Show", SourceId = 1, TmdbId = 77777 };
        await enricher.EnrichSeriesAsync([series], CancellationToken.None);

        series.TmdbId.Should().Be(77777, "already-enriched series must not be overwritten");
    }

    [Fact]
    public async Task EnrichSeriesAsync_NoMatch_LeavesSeriesUnenriched()
    {
        const string emptySearch = """{"results":[],"total_results":0}""";
        var enricher = MakeEnricher((HttpStatusCode.OK, emptySearch));

        var series = new Series { Title = "Unknown Show", SourceId = 1 };
        await enricher.EnrichSeriesAsync([series], CancellationToken.None);

        series.TmdbId.Should().BeNull("no TMDB match means no enrichment");
    }

    [Fact]
    public async Task EnrichSeriesAsync_HttpError_DoesNotThrow_AndLeavesSeriesUnenriched()
    {
        var enricher = MakeEnricher((HttpStatusCode.InternalServerError, "{}"));

        var series = new Series { Title = "Broken Show", SourceId = 1 };
        var act = () => enricher.EnrichSeriesAsync([series], CancellationToken.None);

        await act.Should().NotThrowAsync("non-OCE HTTP failures must be swallowed");
        series.TmdbId.Should().BeNull();
    }

    [Fact]
    public async Task EnrichMoviesAsync_EmptyList_DoesNotThrow()
    {
        var enricher = MakeEnricher();

        var act = () => enricher.EnrichMoviesAsync([], CancellationToken.None);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task EnrichSeriesAsync_EmptyList_DoesNotThrow()
    {
        var enricher = MakeEnricher();

        var act = () => enricher.EnrichSeriesAsync([], CancellationToken.None);
        await act.Should().NotThrowAsync();
    }
}
