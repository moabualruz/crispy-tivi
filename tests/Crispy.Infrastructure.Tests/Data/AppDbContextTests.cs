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

    public void Dispose()
    {
        _factory.Dispose();
    }
}
