using Crispy.Application.Player.Models;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Player;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class BookmarkRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly BookmarkRepository _sut;

    public BookmarkRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new BookmarkRepository(_factory);
    }

    // -------------------------------------------------------------------------
    // GetForContentAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetForContentAsync_ReturnsEmptyList_WhenNoBookmarksExist()
    {
        var result = await _sut.GetForContentAsync("ch1", ContentType.Channel, "profile-1");

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetForContentAsync_ReturnsMatchingBookmarks_OrderedByPositionMs()
    {
        var b1 = MakeBookmark("bk-1", "ch1", ContentType.Channel, "profile-1", positionMs: 5000);
        var b2 = MakeBookmark("bk-2", "ch1", ContentType.Channel, "profile-1", positionMs: 1000);
        var b3 = MakeBookmark("bk-3", "ch1", ContentType.Channel, "profile-1", positionMs: 3000);

        await _sut.AddAsync(b1);
        await _sut.AddAsync(b2);
        await _sut.AddAsync(b3);

        var result = await _sut.GetForContentAsync("ch1", ContentType.Channel, "profile-1");

        result.Should().HaveCount(3);
        result.Select(b => b.PositionMs).Should().BeInAscendingOrder();
    }

    [Fact]
    public async Task GetForContentAsync_ExcludesBookmarks_ForDifferentContent()
    {
        await _sut.AddAsync(MakeBookmark("bk-1", "ch1", ContentType.Channel, "profile-1"));
        await _sut.AddAsync(MakeBookmark("bk-2", "ch2", ContentType.Channel, "profile-1"));
        await _sut.AddAsync(MakeBookmark("bk-3", "ch1", ContentType.Movie, "profile-1"));
        await _sut.AddAsync(MakeBookmark("bk-4", "ch1", ContentType.Channel, "profile-2"));

        var result = await _sut.GetForContentAsync("ch1", ContentType.Channel, "profile-1");

        result.Should().HaveCount(1);
        result[0].Id.Should().Be("bk-1");
    }

    // -------------------------------------------------------------------------
    // AddAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task AddAsync_PersistsBookmark_SoItIsReturnedByGetForContentAsync()
    {
        var bookmark = MakeBookmark("bk-add", "movie-42", ContentType.Movie, "p1", positionMs: 9000);

        await _sut.AddAsync(bookmark);

        var result = await _sut.GetForContentAsync("movie-42", ContentType.Movie, "p1");
        result.Should().HaveCount(1);
        result[0].Id.Should().Be("bk-add");
        result[0].PositionMs.Should().Be(9000);
        result[0].Label.Should().Be(bookmark.Label);
    }

    // -------------------------------------------------------------------------
    // DeleteAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task DeleteAsync_RemovesBookmark_WhenItExists()
    {
        await _sut.AddAsync(MakeBookmark("bk-del", "ch1", ContentType.Channel, "p1"));

        await _sut.DeleteAsync("bk-del");

        var result = await _sut.GetForContentAsync("ch1", ContentType.Channel, "p1");
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task DeleteAsync_DoesNotThrow_WhenBookmarkDoesNotExist()
    {
        var act = async () => await _sut.DeleteAsync("nonexistent-id");

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task DeleteAsync_OnlyRemovesTargetBookmark_LeavingOthersIntact()
    {
        await _sut.AddAsync(MakeBookmark("bk-keep", "ch1", ContentType.Channel, "p1", positionMs: 1000));
        await _sut.AddAsync(MakeBookmark("bk-remove", "ch1", ContentType.Channel, "p1", positionMs: 2000));

        await _sut.DeleteAsync("bk-remove");

        var result = await _sut.GetForContentAsync("ch1", ContentType.Channel, "p1");
        result.Should().HaveCount(1);
        result[0].Id.Should().Be("bk-keep");
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static Bookmark MakeBookmark(
        string id,
        string contentId,
        ContentType contentType,
        string profileId,
        long positionMs = 0) =>
        new()
        {
            Id = id,
            ContentId = contentId,
            ContentType = contentType,
            ProfileId = profileId,
            PositionMs = positionMs,
            Label = $"Label-{id}",
            CreatedAt = DateTimeOffset.UtcNow,
        };

    public void Dispose() => _factory.Dispose();
}
