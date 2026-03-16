using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

[Trait("Category", "Integration")]
public sealed class SeriesRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly SeriesRepository _sut;

    public SeriesRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new SeriesRepository(_factory);
    }

    // -------------------------------------------------------------------------
    // Seed helpers
    // -------------------------------------------------------------------------

    private async Task<Source> SeedSourceAsync()
    {
        await using var ctx = _factory.CreateDbContext();
        var profile = new Profile { Name = "P" };
        ctx.Profiles.Add(profile);
        await ctx.SaveChangesAsync();

        var source = new Source
        {
            Name = "S",
            Url = "http://example.com/source",
            SourceType = SourceType.Jellyfin,
            ProfileId = profile.Id,
        };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();
        return source;
    }

    private async Task<Series> SeedSeriesAsync(int sourceId, string title, int? tmdbId = null)
    {
        await using var ctx = _factory.CreateDbContext();
        var series = new Series
        {
            Title = title,
            SourceId = sourceId,
            TmdbId = tmdbId,
        };
        ctx.SeriesItems.Add(series);
        await ctx.SaveChangesAsync();
        return series;
    }

    private async Task<Episode> SeedEpisodeAsync(int seriesId, int sourceId, int season = 1, int episode = 1)
    {
        await using var ctx = _factory.CreateDbContext();
        var ep = new Episode
        {
            Title = $"S{season:D2}E{episode:D2}",
            SeriesId = seriesId,
            SourceId = sourceId,
            SeasonNumber = season,
            EpisodeNumber = episode,
        };
        ctx.Episodes.Add(ep);
        await ctx.SaveChangesAsync();
        return ep;
    }

    // -------------------------------------------------------------------------
    // GetByIdAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetByIdAsync_ReturnsSeries_WithoutEpisodes_ByDefault()
    {
        var source = await SeedSourceAsync();
        var seeded = await SeedSeriesAsync(source.Id, "Breaking Bad");
        await SeedEpisodeAsync(seeded.Id, source.Id);

        var result = await _sut.GetByIdAsync(seeded.Id);

        result.Should().NotBeNull();
        result!.Title.Should().Be("Breaking Bad");
        result.Episodes.Should().BeEmpty();
    }

    [Fact]
    public async Task GetByIdAsync_IncludesEpisodes_WhenRequested()
    {
        var source = await SeedSourceAsync();
        var seeded = await SeedSeriesAsync(source.Id, "Game of Thrones");
        await SeedEpisodeAsync(seeded.Id, source.Id, season: 1, episode: 1);
        await SeedEpisodeAsync(seeded.Id, source.Id, season: 1, episode: 2);

        var result = await _sut.GetByIdAsync(seeded.Id, includeEpisodes: true);

        result.Should().NotBeNull();
        result!.Episodes.Should().HaveCount(2);
    }

    [Fact]
    public async Task GetByIdAsync_ReturnsNull_WhenNotFound()
    {
        var result = await _sut.GetByIdAsync(99999);

        result.Should().BeNull();
    }

    // -------------------------------------------------------------------------
    // GetBySourceAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetBySourceAsync_ReturnsSeries_ForGivenSource()
    {
        var source = await SeedSourceAsync();
        await SeedSeriesAsync(source.Id, "Show A");
        await SeedSeriesAsync(source.Id, "Show B");

        var result = await _sut.GetBySourceAsync(source.Id);

        result.Should().HaveCount(2);
        result.Should().OnlyContain(s => s.SourceId == source.Id);
    }

    [Fact]
    public async Task GetBySourceAsync_ReturnsEmpty_WhenSourceHasNoSeries()
    {
        var source = await SeedSourceAsync();

        var result = await _sut.GetBySourceAsync(source.Id);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetBySourceAsync_DoesNotReturnSeries_FromOtherSources()
    {
        var source1 = await SeedSourceAsync();
        var source2 = await SeedSourceAsync();
        await SeedSeriesAsync(source1.Id, "Show X");

        var result = await _sut.GetBySourceAsync(source2.Id);

        result.Should().BeEmpty();
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — insert path
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_InsertsNewSeries_ReturnsInsertCount()
    {
        var source = await SeedSourceAsync();
        var items = new[]
        {
            new Series { Title = "Series A", SourceId = source.Id },
            new Series { Title = "Series B", SourceId = source.Id },
        };

        var count = await _sut.UpsertRangeAsync(items);

        count.Should().Be(2);
        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().HaveCount(2);
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — update path (matched by SourceId + Title)
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_UpdatesExistingSeries_WhenSourceIdAndTitleMatch()
    {
        var source = await SeedSourceAsync();
        await SeedSeriesAsync(source.Id, "Stranger Things");

        var updated = new Series
        {
            Title = "Stranger Things",
            SourceId = source.Id,
            Overview = "Updated overview",
            Thumbnail = "http://poster.jpg",
        };

        var count = await _sut.UpsertRangeAsync([updated]);

        count.Should().Be(0); // no new inserts
        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().ContainSingle();
        stored[0].Overview.Should().Be("Updated overview");
        stored[0].Thumbnail.Should().Be("http://poster.jpg");
    }

    [Fact]
    public async Task UpsertRangeAsync_SetsTmdbId_WhenExistingLacksItAndIncomingHasIt()
    {
        var source = await SeedSourceAsync();
        await SeedSeriesAsync(source.Id, "Chernobyl", tmdbId: null);

        var updated = new Series
        {
            Title = "Chernobyl",
            SourceId = source.Id,
            TmdbId = 87108,
        };
        await _sut.UpsertRangeAsync([updated]);

        var stored = await _sut.GetBySourceAsync(source.Id);
        stored[0].TmdbId.Should().Be(87108);
    }

    [Fact]
    public async Task UpsertRangeAsync_DoesNotOverwriteTmdbId_WhenExistingAlreadyHasIt()
    {
        var source = await SeedSourceAsync();
        await SeedSeriesAsync(source.Id, "The Wire", tmdbId: 1438);

        var updated = new Series
        {
            Title = "The Wire",
            SourceId = source.Id,
            TmdbId = 999,
        };
        await _sut.UpsertRangeAsync([updated]);

        var stored = await _sut.GetBySourceAsync(source.Id);
        stored[0].TmdbId.Should().Be(1438);
    }

    // -------------------------------------------------------------------------
    // UpsertEpisodesAsync — insert path
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertEpisodesAsync_InsertsNewEpisodes_ReturnsInsertCount()
    {
        var source = await SeedSourceAsync();
        var series = await SeedSeriesAsync(source.Id, "Sopranos");
        var episodes = new[]
        {
            new Episode { Title = "S01E01", SeriesId = series.Id, SourceId = source.Id, SeasonNumber = 1, EpisodeNumber = 1 },
            new Episode { Title = "S01E02", SeriesId = series.Id, SourceId = source.Id, SeasonNumber = 1, EpisodeNumber = 2 },
        };

        var count = await _sut.UpsertEpisodesAsync(episodes);

        count.Should().Be(2);
        var result = await _sut.GetByIdAsync(series.Id, includeEpisodes: true);
        result!.Episodes.Should().HaveCount(2);
    }

    // -------------------------------------------------------------------------
    // UpsertEpisodesAsync — update path (matched by SeriesId + Season + Episode)
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertEpisodesAsync_UpdatesExistingEpisode_WhenKeyMatches()
    {
        var source = await SeedSourceAsync();
        var series = await SeedSeriesAsync(source.Id, "Lost");
        await SeedEpisodeAsync(series.Id, source.Id, season: 1, episode: 1);

        var updated = new Episode
        {
            Title = "Updated Title",
            SeriesId = series.Id,
            SourceId = source.Id,
            SeasonNumber = 1,
            EpisodeNumber = 1,
            StreamUrl = "http://new-stream.mkv",
            Overview = "New synopsis",
            RuntimeMinutes = 42,
            Thumbnail = "http://thumb.jpg",
        };

        var count = await _sut.UpsertEpisodesAsync([updated]);

        count.Should().Be(0); // no new inserts
        var result = await _sut.GetByIdAsync(series.Id, includeEpisodes: true);
        var ep = result!.Episodes.Single();
        ep.StreamUrl.Should().Be("http://new-stream.mkv");
        ep.Overview.Should().Be("New synopsis");
        ep.RuntimeMinutes.Should().Be(42);
        ep.Thumbnail.Should().Be("http://thumb.jpg");
    }

    public void Dispose() => _factory.Dispose();
}
