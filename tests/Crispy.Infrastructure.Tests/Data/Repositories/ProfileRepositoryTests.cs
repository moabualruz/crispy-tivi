using Crispy.Domain.Entities;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

[Trait("Category", "Integration")]
public sealed class ProfileRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory = new();
    private readonly ProfileRepository _sut;

    public ProfileRepositoryTests()
    {
        _sut = new ProfileRepository(_factory);
    }

    public void Dispose() => _factory.Dispose();

    // ── CreateAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task CreateAsync_ReturnsProfileWithAssignedId_WhenProfileIsValid()
    {
        var profile = new Profile { Name = "Alice" };

        var result = await _sut.CreateAsync(profile);

        result.Id.Should().BeGreaterThan(0);
        result.Name.Should().Be("Alice");
    }

    [Fact]
    public async Task CreateAsync_PersistsProfile_SoItCanBeRetrieved()
    {
        var profile = new Profile { Name = "Bob", AvatarIndex = 2, IsKids = true };

        await _sut.CreateAsync(profile);
        var fetched = await _sut.GetByIdAsync(profile.Id);

        fetched.Should().NotBeNull();
        fetched!.Name.Should().Be("Bob");
        fetched.IsKids.Should().BeTrue();
    }

    // ── GetByIdAsync ─────────────────────────────────────────────────────────

    [Fact]
    public async Task GetByIdAsync_ReturnsNull_WhenIdDoesNotExist()
    {
        var result = await _sut.GetByIdAsync(9999);

        result.Should().BeNull();
    }

    [Fact]
    public async Task GetByIdAsync_ReturnsProfile_WhenIdExists()
    {
        var created = await _sut.CreateAsync(new Profile { Name = "Carol" });

        var result = await _sut.GetByIdAsync(created.Id);

        result.Should().NotBeNull();
        result!.Name.Should().Be("Carol");
    }

    [Fact]
    public async Task GetByIdAsync_IncludesSettings_WhenProfileHasSettings()
    {
        await using var ctx = await _factory.CreateDbContextAsync();
        var profile = new Profile { Name = "Dave" };
        ctx.Profiles.Add(profile);
        await ctx.SaveChangesAsync();

        ctx.Settings.Add(new Setting
        {
            ProfileId = profile.Id,
            Key = "theme",
            Value = "dark",
        });
        await ctx.SaveChangesAsync();

        var result = await _sut.GetByIdAsync(profile.Id);

        result!.Settings.Should().HaveCount(1);
        result.Settings.First().Key.Should().Be("theme");
    }

    // ── GetAllAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task GetAllAsync_ReturnsEmptyList_WhenNoProfilesExist()
    {
        var result = await _sut.GetAllAsync();

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetAllAsync_ReturnsAllProfiles_OrderedByName()
    {
        await _sut.CreateAsync(new Profile { Name = "Zara" });
        await _sut.CreateAsync(new Profile { Name = "Anna" });
        await _sut.CreateAsync(new Profile { Name = "Mike" });

        var result = await _sut.GetAllAsync();

        result.Should().HaveCount(3);
        result.Select(p => p.Name).Should().BeInAscendingOrder();
    }

    [Fact]
    public async Task GetAllAsync_ExcludesSoftDeletedProfiles()
    {
        var active = await _sut.CreateAsync(new Profile { Name = "Active" });
        var deleted = await _sut.CreateAsync(new Profile { Name = "Deleted" });
        await _sut.DeleteAsync(deleted.Id);

        var result = await _sut.GetAllAsync();

        result.Should().ContainSingle(p => p.Id == active.Id);
        result.Should().NotContain(p => p.Id == deleted.Id);
    }

    // ── UpdateAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task UpdateAsync_PersistsChanges_WhenProfileIsModified()
    {
        var profile = await _sut.CreateAsync(new Profile { Name = "Original" });

        profile.Name = "Updated";
        profile.AccentColorIndex = 5;
        await _sut.UpdateAsync(profile);

        var result = await _sut.GetByIdAsync(profile.Id);
        result!.Name.Should().Be("Updated");
        result.AccentColorIndex.Should().Be(5);
    }

    // ── DeleteAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task DeleteAsync_SetsDeletedAt_WhenProfileExists()
    {
        var profile = await _sut.CreateAsync(new Profile { Name = "ToDelete" });

        await _sut.DeleteAsync(profile.Id);

        await using var ctx = await _factory.CreateDbContextAsync();
        // IgnoreQueryFilters bypasses the soft-delete filter so the deleted row is visible.
        var raw = await ctx.Profiles.IgnoreQueryFilters().FirstOrDefaultAsync(p => p.Id == profile.Id);
        raw!.DeletedAt.Should().NotBeNull();
    }

    [Fact]
    public async Task DeleteAsync_DoesNotThrow_WhenIdDoesNotExist()
    {
        var act = async () => await _sut.DeleteAsync(9999);

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task DeleteAsync_HidesProfileFromGetAll_AfterSoftDelete()
    {
        var profile = await _sut.CreateAsync(new Profile { Name = "HideMe" });

        await _sut.DeleteAsync(profile.Id);
        var all = await _sut.GetAllAsync();

        all.Should().NotContain(p => p.Id == profile.Id);
    }
}
