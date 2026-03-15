using Crispy.Infrastructure.Data.Seed;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Seed;

public class DatabaseSeederTests : IDisposable
{
    private readonly TestDbContextFactory _factory;

    public DatabaseSeederTests()
    {
        _factory = new TestDbContextFactory();
    }

    [Fact]
    public async Task SeedAsync_ShouldCreateDefaultProfile_WhenDatabaseIsEmpty()
    {
        await DatabaseSeeder.SeedAsync(_factory);

        await using var context = _factory.CreateDbContext();
        var profiles = await context.Profiles.ToListAsync();

        profiles.Should().ContainSingle()
            .Which.Name.Should().Be("Default");
    }

    [Fact]
    public async Task SeedAsync_ShouldCreateDefaultSettings_WhenDatabaseIsEmpty()
    {
        await DatabaseSeeder.SeedAsync(_factory);

        await using var context = _factory.CreateDbContext();
        var settings = await context.Settings.ToListAsync();

        settings.Should().HaveCount(2);
        settings.Should().Contain(s => s.Key == "theme");
        settings.Should().Contain(s => s.Key == "locale");
    }

    [Fact]
    public async Task SeedAsync_ShouldNotDuplicateData_OnSecondRun()
    {
        await DatabaseSeeder.SeedAsync(_factory);
        await DatabaseSeeder.SeedAsync(_factory);

        await using var context = _factory.CreateDbContext();
        var profiles = await context.Profiles.ToListAsync();

        profiles.Should().ContainSingle();
    }

    public void Dispose()
    {
        _factory.Dispose();
    }
}
