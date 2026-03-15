using Crispy.Domain.Entities;
using Crispy.Infrastructure.Sync;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Sync;

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

    public void Dispose() => _factory.Dispose();
}
