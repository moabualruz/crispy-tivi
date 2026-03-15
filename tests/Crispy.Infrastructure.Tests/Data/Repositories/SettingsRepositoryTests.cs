using Crispy.Domain.Entities;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

public class SettingsRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly SettingsRepository _sut;

    public SettingsRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new SettingsRepository(_factory);
    }

    [Fact]
    public async Task SetAsync_ShouldCreateNewSetting_WhenKeyDoesNotExist()
    {
        await _sut.SetAsync("theme", "dark");

        var result = await _sut.GetAsync("theme");
        result.Should().NotBeNull();
        result!.Value.Should().Be("dark");
    }

    [Fact]
    public async Task SetAsync_ShouldUpdateExistingSetting_WhenKeyExists()
    {
        await _sut.SetAsync("theme", "dark");
        await _sut.SetAsync("theme", "light");

        var result = await _sut.GetAsync("theme");
        result.Should().NotBeNull();
        result!.Value.Should().Be("light");
    }

    [Fact]
    public async Task GetAsync_ShouldReturnNull_WhenKeyDoesNotExist()
    {
        var result = await _sut.GetAsync("nonexistent");

        result.Should().BeNull();
    }

    [Fact]
    public async Task GetAsync_WithProfileId_ShouldReturnProfileSpecificSetting()
    {
        // Create a profile first to satisfy FK constraint
        await using (var context = _factory.CreateDbContext())
        {
            context.Profiles.Add(new Profile { Name = "Test" });
            await context.SaveChangesAsync();
        }

        await _sut.SetAsync("theme", "dark", profileId: null);
        await _sut.SetAsync("theme", "light", profileId: 1);

        var global = await _sut.GetAsync("theme", profileId: null);
        var profile = await _sut.GetAsync("theme", profileId: 1);

        global!.Value.Should().Be("dark");
        profile!.Value.Should().Be("light");
    }

    [Fact]
    public async Task ResetAllAsync_ShouldDeleteAllSettings_ForGivenProfile()
    {
        await _sut.SetAsync("key1", "val1");
        await _sut.SetAsync("key2", "val2");

        await _sut.ResetAllAsync();

        var results = await _sut.GetAllAsync();
        results.Should().BeEmpty();
    }

    [Fact]
    public async Task ResetCategoryAsync_ShouldDeleteOnlyMatchingKeys()
    {
        await _sut.SetAsync("player.volume", "80");
        await _sut.SetAsync("player.speed", "1.0");
        await _sut.SetAsync("theme", "dark");

        await _sut.ResetCategoryAsync("player.");

        var results = await _sut.GetAllAsync();
        results.Should().ContainSingle()
            .Which.Key.Should().Be("theme");
    }

    [Fact]
    public async Task DeleteAsync_ShouldRemoveSpecificSetting()
    {
        await _sut.SetAsync("key1", "val1");
        await _sut.SetAsync("key2", "val2");

        await _sut.DeleteAsync("key1");

        var result = await _sut.GetAsync("key1");
        result.Should().BeNull();

        var remaining = await _sut.GetAsync("key2");
        remaining.Should().NotBeNull();
    }

    public void Dispose()
    {
        _factory.Dispose();
    }
}
