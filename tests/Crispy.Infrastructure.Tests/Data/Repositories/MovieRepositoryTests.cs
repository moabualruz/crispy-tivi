using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

[Trait("Category", "Integration")]
public sealed class MovieRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly MovieRepository _sut;

    public MovieRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new MovieRepository(_factory);
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

    private async Task<Movie> SeedMovieAsync(int sourceId, string title, int? tmdbId = null)
    {
        await using var ctx = _factory.CreateDbContext();
        var movie = new Movie
        {
            Title = title,
            SourceId = sourceId,
            StreamUrl = $"http://example.com/{title}.mkv",
            TmdbId = tmdbId,
        };
        ctx.Movies.Add(movie);
        await ctx.SaveChangesAsync();
        return movie;
    }

    // -------------------------------------------------------------------------
    // GetByIdAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetByIdAsync_ReturnsMovie_WhenExists()
    {
        var source = await SeedSourceAsync();
        var seeded = await SeedMovieAsync(source.Id, "Inception");

        var result = await _sut.GetByIdAsync(seeded.Id);

        result.Should().NotBeNull();
        result!.Title.Should().Be("Inception");
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
    public async Task GetBySourceAsync_ReturnsMovies_ForGivenSource()
    {
        var source = await SeedSourceAsync();
        await SeedMovieAsync(source.Id, "Movie A");
        await SeedMovieAsync(source.Id, "Movie B");

        var result = await _sut.GetBySourceAsync(source.Id);

        result.Should().HaveCount(2);
        result.Should().OnlyContain(m => m.SourceId == source.Id);
    }

    [Fact]
    public async Task GetBySourceAsync_ReturnsEmpty_WhenSourceHasNoMovies()
    {
        var source = await SeedSourceAsync();

        var result = await _sut.GetBySourceAsync(source.Id);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetBySourceAsync_DoesNotReturnMovies_FromOtherSources()
    {
        var source1 = await SeedSourceAsync();
        var source2 = await SeedSourceAsync();
        await SeedMovieAsync(source1.Id, "Movie X");

        var result = await _sut.GetBySourceAsync(source2.Id);

        result.Should().BeEmpty();
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — insert path
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_InsertsNewMovies_ReturnsInsertCount()
    {
        var source = await SeedSourceAsync();
        var movies = new[]
        {
            new Movie { Title = "Film A", SourceId = source.Id, StreamUrl = "http://a.mkv" },
            new Movie { Title = "Film B", SourceId = source.Id, StreamUrl = "http://b.mkv" },
        };

        var count = await _sut.UpsertRangeAsync(movies);

        count.Should().Be(2);
        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().HaveCount(2);
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — update path (matched by SourceId + Title)
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_UpdatesExistingMovie_WhenSourceIdAndTitleMatch()
    {
        var source = await SeedSourceAsync();
        await SeedMovieAsync(source.Id, "The Matrix");

        var updated = new Movie
        {
            Title = "The Matrix",
            SourceId = source.Id,
            StreamUrl = "http://new-url.mkv",
            Overview = "Updated overview",
            Year = 1999,
            RuntimeMinutes = 136,
            Thumbnail = "http://poster.jpg",
        };

        var count = await _sut.UpsertRangeAsync([updated]);

        count.Should().Be(0); // no new inserts
        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().ContainSingle();
        stored[0].StreamUrl.Should().Be("http://new-url.mkv");
        stored[0].Overview.Should().Be("Updated overview");
        stored[0].Year.Should().Be(1999);
    }

    [Fact]
    public async Task UpsertRangeAsync_SetsTmdbId_WhenExistingLacksItAndIncomingHasIt()
    {
        var source = await SeedSourceAsync();
        await SeedMovieAsync(source.Id, "Interstellar", tmdbId: null);

        var updated = new Movie
        {
            Title = "Interstellar",
            SourceId = source.Id,
            TmdbId = 157336,
        };
        await _sut.UpsertRangeAsync([updated]);

        var stored = await _sut.GetBySourceAsync(source.Id);
        stored[0].TmdbId.Should().Be(157336);
    }

    [Fact]
    public async Task UpsertRangeAsync_DoesNotOverwriteTmdbId_WhenExistingAlreadyHasIt()
    {
        var source = await SeedSourceAsync();
        await SeedMovieAsync(source.Id, "Dune", tmdbId: 438631);

        var updated = new Movie
        {
            Title = "Dune",
            SourceId = source.Id,
            TmdbId = 999,
        };
        await _sut.UpsertRangeAsync([updated]);

        var stored = await _sut.GetBySourceAsync(source.Id);
        stored[0].TmdbId.Should().Be(438631);
    }

    public void Dispose() => _factory.Dispose();
}
