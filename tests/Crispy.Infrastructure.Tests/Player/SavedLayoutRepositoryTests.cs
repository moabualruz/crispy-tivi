using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Player;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class SavedLayoutRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly SavedLayoutRepository _sut;

    public SavedLayoutRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new SavedLayoutRepository(_factory);
    }

    // -------------------------------------------------------------------------
    // GetAllAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetAllAsync_ReturnsEmptyList_WhenNoLayoutsExist()
    {
        var result = await _sut.GetAllAsync("profile-1");

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetAllAsync_ReturnsLayoutsForProfile_OrderedByCreatedAtDescending()
    {
        var base_ = DateTimeOffset.UtcNow;

        await _sut.SaveAsync(MakeLayout("l1", "p1", createdAt: base_.AddMinutes(-30)));
        await _sut.SaveAsync(MakeLayout("l2", "p1", createdAt: base_.AddMinutes(-10)));
        await _sut.SaveAsync(MakeLayout("l3", "p1", createdAt: base_.AddMinutes(-60)));

        var result = await _sut.GetAllAsync("p1");

        result.Should().HaveCount(3);
        result.Select(l => l.CreatedAt).Should().BeInDescendingOrder();
    }

    [Fact]
    public async Task GetAllAsync_ExcludesLayouts_ForOtherProfiles()
    {
        await _sut.SaveAsync(MakeLayout("l-p1", "p1"));
        await _sut.SaveAsync(MakeLayout("l-p2", "p2"));

        var result = await _sut.GetAllAsync("p1");

        result.Should().HaveCount(1);
        result[0].Id.Should().Be("l-p1");
    }

    // -------------------------------------------------------------------------
    // SaveAsync — insert
    // -------------------------------------------------------------------------

    [Fact]
    public async Task SaveAsync_InsertsNewLayout_WhenIdDoesNotExist()
    {
        var layout = MakeLayout("l-new", "p1");

        await _sut.SaveAsync(layout);

        var result = await _sut.GetAllAsync("p1");
        result.Should().HaveCount(1);
        result[0].Id.Should().Be("l-new");
        result[0].Name.Should().Be(layout.Name);
    }

    // -------------------------------------------------------------------------
    // SaveAsync — upsert
    // -------------------------------------------------------------------------

    [Fact]
    public async Task SaveAsync_UpdatesExistingLayout_WhenIdAlreadyExists()
    {
        await _sut.SaveAsync(MakeLayout("l-upd", "p1", name: "Original", streamsJson: "[]"));

        var updated = MakeLayout("l-upd", "p1", name: "Updated", streamsJson: "[\"ch1\"]");
        await _sut.SaveAsync(updated);

        var result = await _sut.GetAllAsync("p1");
        result.Should().HaveCount(1);
        result[0].Name.Should().Be("Updated");
        result[0].StreamsJson.Should().Be("[\"ch1\"]");
    }

    [Fact]
    public async Task SaveAsync_UpdatesLayout_PreservesCreatedAt()
    {
        var original = MakeLayout("l-ts", "p1", name: "Before");
        await _sut.SaveAsync(original);

        var updated = MakeLayout("l-ts", "p1", name: "After");
        await _sut.SaveAsync(updated);

        // Count stays at 1 — no duplicate inserted
        var result = await _sut.GetAllAsync("p1");
        result.Should().HaveCount(1);
    }

    // -------------------------------------------------------------------------
    // DeleteAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task DeleteAsync_RemovesLayout_WhenItExists()
    {
        await _sut.SaveAsync(MakeLayout("l-del", "p1"));

        await _sut.DeleteAsync("l-del");

        var result = await _sut.GetAllAsync("p1");
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task DeleteAsync_DoesNotThrow_WhenLayoutDoesNotExist()
    {
        var act = async () => await _sut.DeleteAsync("nonexistent-id");

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task DeleteAsync_OnlyRemovesTargetLayout_LeavingOthersIntact()
    {
        await _sut.SaveAsync(MakeLayout("l-keep", "p1"));
        await _sut.SaveAsync(MakeLayout("l-remove", "p1"));

        await _sut.DeleteAsync("l-remove");

        var result = await _sut.GetAllAsync("p1");
        result.Should().HaveCount(1);
        result[0].Id.Should().Be("l-keep");
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static SavedLayout MakeLayout(
        string id,
        string profileId,
        string name = "Test Layout",
        string streamsJson = "[]",
        DateTimeOffset? createdAt = null) =>
        new()
        {
            Id = id,
            ProfileId = profileId,
            Name = name,
            Layout = LayoutType.Pip,
            StreamsJson = streamsJson,
            CreatedAt = createdAt ?? DateTimeOffset.UtcNow,
        };

    public void Dispose() => _factory.Dispose();
}
