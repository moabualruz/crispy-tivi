using Crispy.Domain.Entities;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data;

public class AppDbContextTests : IDisposable
{
    private readonly TestDbContextFactory _factory;

    public AppDbContextTests()
    {
        _factory = new TestDbContextFactory();
    }

    [Fact]
    public async Task SaveChangesAsync_ShouldAutoSetCreatedAt_OnNewEntities()
    {
        await using var context = _factory.CreateDbContext();
        var before = DateTime.UtcNow;

        var profile = new Profile { Name = "Test" };
        context.Profiles.Add(profile);
        await context.SaveChangesAsync();

        profile.CreatedAt.Should().BeOnOrAfter(before);
        profile.CreatedAt.Should().BeOnOrBefore(DateTime.UtcNow);
    }

    [Fact]
    public async Task SaveChangesAsync_ShouldAutoSetUpdatedAt_OnModifiedEntities()
    {
        await using var context = _factory.CreateDbContext();
        var profile = new Profile { Name = "Test" };
        context.Profiles.Add(profile);
        await context.SaveChangesAsync();

        var createdAt = profile.UpdatedAt;

        // Small delay to ensure different timestamp
        await Task.Delay(10);

        profile.Name = "Updated";
        context.Profiles.Update(profile);
        await context.SaveChangesAsync();

        profile.UpdatedAt.Should().BeOnOrAfter(createdAt);
    }

    [Fact]
    public async Task SoftDeleteFilter_ShouldExcludeDeletedEntities()
    {
        await using var context = _factory.CreateDbContext();
        var profile1 = new Profile { Name = "Active" };
        var profile2 = new Profile { Name = "Deleted", DeletedAt = DateTime.UtcNow };
        context.Profiles.AddRange(profile1, profile2);
        await context.SaveChangesAsync();

        var results = await context.Profiles.ToListAsync();

        results.Should().ContainSingle()
            .Which.Name.Should().Be("Active");
    }

    [Fact]
    public async Task SoftDeleteFilter_ShouldIncludeDeletedEntities_WhenIgnored()
    {
        await using var context = _factory.CreateDbContext();
        var profile1 = new Profile { Name = "Active" };
        var profile2 = new Profile { Name = "Deleted", DeletedAt = DateTime.UtcNow };
        context.Profiles.AddRange(profile1, profile2);
        await context.SaveChangesAsync();

        var results = await context.Profiles.IgnoreQueryFilters().ToListAsync();

        results.Should().HaveCount(2);
    }

    [Fact]
    public async Task AllDbSets_ShouldBeNonNull_AfterContextCreation()
    {
        await using var context = _factory.CreateDbContext();

        context.Profiles.Should().NotBeNull();
        context.Settings.Should().NotBeNull();
        context.Sources.Should().NotBeNull();
        context.Channels.Should().NotBeNull();
        context.ChannelGroups.Should().NotBeNull();
        context.ChannelGroupMemberships.Should().NotBeNull();
        context.DeduplicationGroups.Should().NotBeNull();
        context.StreamEndpoints.Should().NotBeNull();
        context.Movies.Should().NotBeNull();
        context.SeriesItems.Should().NotBeNull();
        context.Episodes.Should().NotBeNull();
        context.WatchHistory.Should().NotBeNull();
        context.WatchHistoryEntries.Should().NotBeNull();
        context.Bookmarks.Should().NotBeNull();
        context.SavedLayouts.Should().NotBeNull();
        context.Reminders.Should().NotBeNull();
        context.StreamHealthEntries.Should().NotBeNull();
        context.SyncHistory.Should().NotBeNull();
        context.Downloads.Should().NotBeNull();
    }

    [Fact]
    public async Task OnModelCreating_ShouldConfigureAllEntityTypes_WithoutError()
    {
        // If OnModelCreating threw, EnsureCreated() in the factory would have failed.
        // Reaching this point means model configuration succeeded.
        await using var context = _factory.CreateDbContext();
        var entityTypes = context.Model.GetEntityTypes().Select(e => e.ClrType.Name).ToList();

        entityTypes.Should().Contain("Profile");
        entityTypes.Should().Contain("Setting");
        entityTypes.Should().Contain("Source");
        entityTypes.Should().Contain("Channel");
        entityTypes.Should().Contain("Movie");
        entityTypes.Should().Contain("Series");
        entityTypes.Should().Contain("Episode");
    }

    [Fact]
    public async Task SaveChangesAsync_ShouldSetUpdatedAt_WhenEntityIsModified()
    {
        await using var context = _factory.CreateDbContext();
        var profile = new Profile { Name = "Initial" };
        context.Profiles.Add(profile);
        await context.SaveChangesAsync();
        var originalUpdatedAt = profile.UpdatedAt;

        await Task.Delay(15);

        profile.Name = "Modified";
        await context.SaveChangesAsync();

        profile.UpdatedAt.Should().BeOnOrAfter(originalUpdatedAt);
        profile.CreatedAt.Should().BeOnOrBefore(profile.UpdatedAt);
    }

    [Fact]
    public async Task SoftDelete_ShouldMarkEntityAsDeleted_WhenDeletedAtSet()
    {
        await using var context = _factory.CreateDbContext();
        var profile = new Profile { Name = "ToDelete" };
        context.Profiles.Add(profile);
        await context.SaveChangesAsync();

        profile.DeletedAt = DateTime.UtcNow;
        await context.SaveChangesAsync();

        // Query filter excludes it from normal queries
        var active = await context.Profiles.ToListAsync();
        active.Should().NotContain(p => p.Name == "ToDelete");

        // But it still exists when filters are ignored
        var all = await context.Profiles.IgnoreQueryFilters().ToListAsync();
        all.Should().Contain(p => p.Name == "ToDelete" && p.DeletedAt != null);
    }

    public void Dispose()
    {
        _factory.Dispose();
    }
}
