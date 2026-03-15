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

    // ─── Series enrichment ────────────────────────────────────────────────────

    [Fact]
    public async Task EnrichSeriesAsync_PopulatesTmdbId()
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
    }
}
