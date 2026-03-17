using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

[Trait("Category", "Integration")]
public sealed class ChannelRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly ChannelRepository _sut;

    public ChannelRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new ChannelRepository(_factory);
    }

    // -------------------------------------------------------------------------
    // Seed helpers
    // -------------------------------------------------------------------------

    private async Task<(Profile Profile, Source Source)> SeedProfileAndSourceAsync()
    {
        await using var ctx = _factory.CreateDbContext();
        var profile = new Profile { Name = "P" };
        ctx.Profiles.Add(profile);
        await ctx.SaveChangesAsync();

        var source = new Source
        {
            Name = "S",
            Url = "http://example.com/playlist.m3u",
            SourceType = SourceType.M3U,
            ProfileId = profile.Id,
        };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        return (profile, source);
    }

    private static Channel MakeChannel(int sourceId, string title, string? tvgId = null, int? tvgChno = null) =>
        new()
        {
            Title = title,
            SourceId = sourceId,
            TvgId = tvgId,
            TvgChno = tvgChno,
        };

    private async Task<Channel> SeedChannelAsync(int sourceId, string title, string? tvgId = null, int? tvgChno = null)
    {
        await using var ctx = _factory.CreateDbContext();
        var ch = MakeChannel(sourceId, title, tvgId, tvgChno);
        ctx.Channels.Add(ch);
        await ctx.SaveChangesAsync();
        return ch;
    }

    // -------------------------------------------------------------------------
    // GetByIdAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetByIdAsync_ReturnsChannel_WithStreamEndpoints_WhenExists()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        var seeded = await SeedChannelAsync(source.Id, "CNN", tvgId: "cnn");

        var result = await _sut.GetByIdAsync(seeded.Id);

        result.Should().NotBeNull();
        result!.Title.Should().Be("CNN");
        result.StreamEndpoints.Should().NotBeNull();
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
    public async Task GetBySourceAsync_ReturnsChannels_ForGivenSource_OrderedByChannelNumber()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        await SeedChannelAsync(source.Id, "Ch3", tvgChno: 3);
        await SeedChannelAsync(source.Id, "Ch1", tvgChno: 1);
        await SeedChannelAsync(source.Id, "Ch2", tvgChno: 2);

        var result = await _sut.GetBySourceAsync(source.Id);

        result.Should().HaveCount(3);
        result[0].TvgChno.Should().Be(1);
        result[1].TvgChno.Should().Be(2);
        result[2].TvgChno.Should().Be(3);
    }

    [Fact]
    public async Task GetBySourceAsync_ReturnsEmpty_WhenSourceHasNoChannels()
    {
        var (_, source) = await SeedProfileAndSourceAsync();

        var result = await _sut.GetBySourceAsync(source.Id);

        result.Should().BeEmpty();
    }

    // -------------------------------------------------------------------------
    // GetAllAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetAllAsync_ReturnsAllChannels_AcrossSources()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        await SeedChannelAsync(source.Id, "Ch1", tvgId: "ch1");
        await SeedChannelAsync(source.Id, "Ch2", tvgId: "ch2");

        var result = await _sut.GetAllAsync();

        result.Should().HaveCount(2);
    }

    [Fact]
    public async Task GetAllAsync_ReturnsEmpty_WhenNoChannelsExist()
    {
        var result = await _sut.GetAllAsync();

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetAllAsync_IncludesStreamEndpoints()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        var ch = await SeedChannelAsync(source.Id, "WithEndpoint", tvgId: "ep1");

        // Add a stream endpoint
        await using var ctx = _factory.CreateDbContext();
        ctx.StreamEndpoints.Add(new StreamEndpoint
        {
            ChannelId = ch.Id,
            SourceId = source.Id,
            Url = "http://stream.ts",
            Priority = 1,
        });
        await ctx.SaveChangesAsync();

        var result = await _sut.GetAllAsync();

        result.Should().ContainSingle()
            .Which.StreamEndpoints.Should().ContainSingle();
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — empty list
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_ReturnsZero_WhenEmptyList()
    {
        var count = await _sut.UpsertRangeAsync([]);

        count.Should().Be(0);
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — insert path
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_InsertsNewChannels_ReturnsCount()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        var channels = new[]
        {
            MakeChannel(source.Id, "BBC One", tvgId: "bbc1"),
            MakeChannel(source.Id, "BBC Two", tvgId: "bbc2"),
        };

        var count = await _sut.UpsertRangeAsync(channels);

        count.Should().Be(2);
        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().HaveCount(2);
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — update path (matched by TvgId)
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_UpdatesExistingChannel_WhenTvgIdMatches()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        await SeedChannelAsync(source.Id, "Old Title", tvgId: "ch1");

        var updated = new[] { MakeChannel(source.Id, "New Title", tvgId: "ch1") };
        await _sut.UpsertRangeAsync(updated);

        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().ContainSingle()
            .Which.Title.Should().Be("New Title");
    }

    // -------------------------------------------------------------------------
    // UpsertRangeAsync — update path (matched by Title when no TvgId)
    // -------------------------------------------------------------------------

    [Fact]
    public async Task UpsertRangeAsync_UpdatesExistingChannel_ByTitle_WhenNoTvgId()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        await SeedChannelAsync(source.Id, "MyChannel");

        var updated = new[] { MakeChannel(source.Id, "MyChannel") };
        var count = await _sut.UpsertRangeAsync(updated);

        count.Should().Be(1); // still counted
        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().ContainSingle();
    }

    // -------------------------------------------------------------------------
    // IncrementMissedSyncAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task IncrementMissedSyncAsync_IncrementsCount_ForAbsentChannels()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        await SeedChannelAsync(source.Id, "Present", tvgId: "present");
        var absent = await SeedChannelAsync(source.Id, "Absent", tvgId: "absent");

        await _sut.IncrementMissedSyncAsync(source.Id, ["present"]);

        var result = await _sut.GetByIdAsync(absent.Id);
        result!.MissedSyncCount.Should().Be(1);
    }

    [Fact]
    public async Task IncrementMissedSyncAsync_DoesNotIncrement_ForPresentChannels()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        var present = await SeedChannelAsync(source.Id, "Present", tvgId: "present");

        await _sut.IncrementMissedSyncAsync(source.Id, ["present"]);

        var result = await _sut.GetByIdAsync(present.Id);
        result!.MissedSyncCount.Should().Be(0);
    }

    // -------------------------------------------------------------------------
    // SoftRemoveExpiredAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task SoftRemoveExpiredAsync_SoftDeletesChannels_AtOrAboveThreshold()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        var ch = await SeedChannelAsync(source.Id, "Expired", tvgId: "exp");

        // Manually bump missed sync count above threshold
        await using var ctx = _factory.CreateDbContext();
        var entity = await ctx.Channels.FindAsync(ch.Id);
        entity!.MissedSyncCount = 5;
        await ctx.SaveChangesAsync();

        await _sut.SoftRemoveExpiredAsync(source.Id, threshold: 3);

        // Normal query returns nothing (soft-delete filter)
        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().BeEmpty();

        // Confirm soft-deleted
        await using var ctx2 = _factory.CreateDbContext();
        var raw = ctx2.Channels.IgnoreQueryFilters().FirstOrDefault(c => c.Id == ch.Id);
        raw!.DeletedAt.Should().NotBeNull();
    }

    [Fact]
    public async Task SoftRemoveExpiredAsync_DoesNotDelete_ChannelsBelowThreshold()
    {
        var (_, source) = await SeedProfileAndSourceAsync();
        var ch = await SeedChannelAsync(source.Id, "Active", tvgId: "active");

        await using var ctx = _factory.CreateDbContext();
        var entity = await ctx.Channels.FindAsync(ch.Id);
        entity!.MissedSyncCount = 1;
        await ctx.SaveChangesAsync();

        await _sut.SoftRemoveExpiredAsync(source.Id, threshold: 3);

        var stored = await _sut.GetBySourceAsync(source.Id);
        stored.Should().ContainSingle();
    }

    public void Dispose() => _factory.Dispose();
}
