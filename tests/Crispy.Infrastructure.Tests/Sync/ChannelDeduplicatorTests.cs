using Crispy.Domain.Entities;
using Crispy.Infrastructure.Sync;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Sync;

[Trait("Category", "Unit")]
public class ChannelDeduplicatorTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private int _src1Id;
    private int _src2Id;

    public ChannelDeduplicatorTests()
    {
        _factory = new TestDbContextFactory();
        SeedData();
    }

    private void SeedData()
    {
        using var ctx = _factory.CreateDbContext();

        // Profile (required FK)
        var profile = new Profile { Name = "Test" };
        ctx.Profiles.Add(profile);
        ctx.SaveChanges();

        // Two sources
        var src1 = new Source { Name = "Source1", Url = "http://s1.com", ProfileId = profile.Id, SortOrder = 1 };
        var src2 = new Source { Name = "Source2", Url = "http://s2.com", ProfileId = profile.Id, SortOrder = 2 };
        ctx.Sources.AddRange(src1, src2);
        ctx.SaveChanges();

        _src1Id = src1.Id;
        _src2Id = src2.Id;

        // Two channels with the same TvgId from different sources
        ctx.Channels.AddRange(
            new Channel { Title = "BBC One", TvgId = "bbc1.uk", SourceId = src1.Id },
            new Channel { Title = "BBC One HD", TvgId = "bbc1.uk", SourceId = src2.Id },
            new Channel { Title = "CNN", TvgId = "cnn.us", SourceId = src1.Id }
        );
        ctx.SaveChanges();
    }

    [Fact]
    public async Task RunAsync_SameTvgIdFromTwoSources_CreatesOneDeduplicationGroup()
    {
        var deduplicator = new ChannelDeduplicator(_factory);

        await deduplicator.RunAsync(CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        var groups = ctx.DeduplicationGroups.ToList();
        groups.Should().HaveCount(1, "BBC One appears in two sources with same tvg-id");
        groups[0].CanonicalTvgId.Should().Be("bbc1.uk");
    }

    [Fact]
    public async Task RunAsync_ManualLink_NotOverwrittenByAutoDedup()
    {
        // Create a dedup group manually before auto-dedup runs
        using var ctx = _factory.CreateDbContext();

        var manualGroup = new DeduplicationGroup
        {
            CanonicalTitle = "BBC One Manual",
            CanonicalTvgId = "bbc1.uk",
        };
        ctx.DeduplicationGroups.Add(manualGroup);
        ctx.SaveChanges();

        var groupId = manualGroup.Id;
        var originalTitle = manualGroup.CanonicalTitle;

        // Run deduplicator — should not delete or rename the existing group
        var deduplicator = new ChannelDeduplicator(_factory);
        await deduplicator.RunAsync(CancellationToken.None);

        using var ctx2 = _factory.CreateDbContext();
        var group = ctx2.DeduplicationGroups.FirstOrDefault(g => g.Id == groupId);
        group.Should().NotBeNull("pre-existing group must not be deleted");
        group!.CanonicalTitle.Should().Be(originalTitle, "pre-existing group title must not change");
    }

    [Fact]
    public async Task RunAsync_SingleUniqueChannel_CreatesNoGroup()
    {
        // CNN has TvgId "cnn.us" but only appears in one source — no dedup needed
        var deduplicator = new ChannelDeduplicator(_factory);

        await deduplicator.RunAsync(CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        // Only BBC One (bbc1.uk, 2 sources) should produce a group — CNN should not
        var groups = ctx.DeduplicationGroups.ToList();
        groups.Should().NotContain(g => g.CanonicalTvgId == "cnn.us",
            "channels unique to one source must not create a deduplication group");
    }

    [Fact]
    public async Task RunAsync_EmptyDatabase_CreatesNoGroups()
    {
        // Use a fresh factory with no channels
        using var emptyFactory = new TestDbContextFactory();
        using var ctx = emptyFactory.CreateDbContext();
        var profile = new Profile { Name = "Empty" };
        ctx.Profiles.Add(profile);
        ctx.SaveChanges();

        var deduplicator = new ChannelDeduplicator(emptyFactory);
        await deduplicator.RunAsync(CancellationToken.None);

        using var ctx2 = emptyFactory.CreateDbContext();
        ctx2.DeduplicationGroups.Should().BeEmpty("no channels means no dedup groups");
    }

    [Fact]
    public async Task RunAsync_ExistingGroup_NewMemberAdded_WhenThirdSourceAppears()
    {
        // First run creates a group for bbc1.uk with 2 channels
        var deduplicator = new ChannelDeduplicator(_factory);
        await deduplicator.RunAsync(CancellationToken.None);

        // Add a third source with the same TvgId
        using (var ctx = _factory.CreateDbContext())
        {
            var profile = ctx.Profiles.First();
            var src3 = new Source { Name = "Source3", Url = "http://s3.com", ProfileId = profile.Id, SortOrder = 3 };
            ctx.Sources.Add(src3);
            ctx.SaveChanges();
            ctx.Channels.Add(new Channel { Title = "BBC One FHD", TvgId = "bbc1.uk", SourceId = src3.Id });
            ctx.SaveChanges();
        }

        // Second run — should add the new channel to the existing group
        await deduplicator.RunAsync(CancellationToken.None);

        using var ctx2 = _factory.CreateDbContext();
        var group = ctx2.DeduplicationGroups
            .Include(g => g.Channels)
            .FirstOrDefault(g => g.CanonicalTvgId == "bbc1.uk");
        group.Should().NotBeNull();
        group!.Channels.Should().HaveCount(3, "all three sources contribute to the same bbc1.uk group");
    }

    [Fact]
    public async Task RunAsync_PrimaryChannelIsLowestSourceId()
    {
        // src1 has lower Id than src2, so src1's channel should be canonical title source
        var deduplicator = new ChannelDeduplicator(_factory);
        await deduplicator.RunAsync(CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        var group = ctx.DeduplicationGroups.First(g => g.CanonicalTvgId == "bbc1.uk");

        // Primary = lowest SourceId = src1 → Title = "BBC One"
        group.CanonicalTitle.Should().Be("BBC One",
            "the channel from the lowest SourceId is the primary and sets CanonicalTitle");
    }

    public void Dispose() => _factory.Dispose();
}
