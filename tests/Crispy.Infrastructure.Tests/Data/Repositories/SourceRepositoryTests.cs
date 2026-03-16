using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

[Trait("Category", "Integration")]
public sealed class SourceRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly SourceRepository _sut;

    public SourceRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new SourceRepository(_factory);
    }

    // -------------------------------------------------------------------------
    // Seed helpers
    // -------------------------------------------------------------------------

    private async Task<Profile> SeedProfileAsync(string name = "Default")
    {
        await using var ctx = _factory.CreateDbContext();
        var profile = new Profile { Name = name };
        ctx.Profiles.Add(profile);
        await ctx.SaveChangesAsync();
        return profile;
    }

    private async Task<Source> SeedSourceAsync(int profileId, string name = "Source1", int sortOrder = 0)
    {
        await using var ctx = _factory.CreateDbContext();
        var source = new Source
        {
            Name = name,
            Url = "http://example.com/playlist.m3u",
            SourceType = SourceType.M3U,
            ProfileId = profileId,
            SortOrder = sortOrder,
        };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();
        return source;
    }

    // -------------------------------------------------------------------------
    // GetAllAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetAllAsync_ReturnsEmptyList_WhenNoSourcesExist()
    {
        var result = await _sut.GetAllAsync();

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllSources_OrderedBySortOrderThenName()
    {
        var profile = await SeedProfileAsync();
        await SeedSourceAsync(profile.Id, "Beta", sortOrder: 2);
        await SeedSourceAsync(profile.Id, "Alpha", sortOrder: 1);
        await SeedSourceAsync(profile.Id, "Gamma", sortOrder: 1);

        var result = await _sut.GetAllAsync();

        result.Should().HaveCount(3);
        result[0].Name.Should().Be("Alpha");
        result[1].Name.Should().Be("Gamma");
        result[2].Name.Should().Be("Beta");
    }

    // -------------------------------------------------------------------------
    // GetByIdAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetByIdAsync_ReturnsSource_WhenExists()
    {
        var profile = await SeedProfileAsync();
        var seeded = await SeedSourceAsync(profile.Id);

        var result = await _sut.GetByIdAsync(seeded.Id);

        result.Should().NotBeNull();
        result!.Name.Should().Be(seeded.Name);
    }

    [Fact]
    public async Task GetByIdAsync_ReturnsNull_WhenNotFound()
    {
        var result = await _sut.GetByIdAsync(99999);

        result.Should().BeNull();
    }

    // -------------------------------------------------------------------------
    // GetByProfileAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetByProfileAsync_ReturnsOnlySourcesForProfile()
    {
        var profile1 = await SeedProfileAsync("P1");
        var profile2 = await SeedProfileAsync("P2");
        await SeedSourceAsync(profile1.Id, "S-P1");
        await SeedSourceAsync(profile2.Id, "S-P2a");
        await SeedSourceAsync(profile2.Id, "S-P2b");

        var result = await _sut.GetByProfileAsync(profile2.Id);

        result.Should().HaveCount(2);
        result.Should().OnlyContain(s => s.ProfileId == profile2.Id);
    }

    [Fact]
    public async Task GetByProfileAsync_ReturnsEmpty_WhenProfileHasNoSources()
    {
        var profile = await SeedProfileAsync();

        var result = await _sut.GetByProfileAsync(profile.Id);

        result.Should().BeEmpty();
    }

    // -------------------------------------------------------------------------
    // CreateAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task CreateAsync_PersistsSource_AndReturnsWithId()
    {
        var profile = await SeedProfileAsync();
        var source = new Source
        {
            Name = "New Source",
            Url = "http://example.com/new.m3u",
            SourceType = SourceType.XtreamCodes,
            ProfileId = profile.Id,
        };

        var created = await _sut.CreateAsync(source);

        created.Id.Should().BeGreaterThan(0);
        var fetched = await _sut.GetByIdAsync(created.Id);
        fetched.Should().NotBeNull();
        fetched!.Name.Should().Be("New Source");
    }

    // -------------------------------------------------------------------------
    // UpdateAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpdateAsync_PersistsChanges()
    {
        var profile = await SeedProfileAsync();
        var seeded = await SeedSourceAsync(profile.Id, "Original");

        seeded.Name = "Updated";
        await _sut.UpdateAsync(seeded);

        var fetched = await _sut.GetByIdAsync(seeded.Id);
        fetched!.Name.Should().Be("Updated");
    }

    // -------------------------------------------------------------------------
    // DeleteAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task DeleteAsync_SoftDeletesSource_BySettingDeletedAt()
    {
        var profile = await SeedProfileAsync();
        var seeded = await SeedSourceAsync(profile.Id);

        await _sut.DeleteAsync(seeded.Id);

        // Soft-deleted entity is excluded from normal queries
        var result = await _sut.GetByIdAsync(seeded.Id);
        result.Should().BeNull();

        // Verify the DeletedAt was set directly in DB
        await using var ctx = _factory.CreateDbContext();
        var raw = await ctx.Sources.FindAsync(seeded.Id);
        raw.Should().BeNull(); // query filter active on FindAsync path too

        // Use IgnoreQueryFilters to confirm soft-delete state
        var rawIgnored = ctx.Sources.IgnoreQueryFilters().FirstOrDefault(s => s.Id == seeded.Id);
        rawIgnored.Should().NotBeNull();
        rawIgnored!.DeletedAt.Should().NotBeNull();
    }

    [Fact]
    public async Task DeleteAsync_DoesNotThrow_WhenIdDoesNotExist()
    {
        var act = () => _sut.DeleteAsync(99999);

        await act.Should().NotThrowAsync();
    }

    public void Dispose() => _factory.Dispose();
}
