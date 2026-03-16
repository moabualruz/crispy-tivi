using Crispy.Application.Search;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Search;

[Trait("Category", "Unit")]
public class SearchResultsTests
{
    [Fact]
    public void DefaultConstructor_AllCollectionsAreEmpty()
    {
        var results = new SearchResults();

        results.Channels.Should().BeEmpty();
        results.Movies.Should().BeEmpty();
        results.Series.Should().BeEmpty();
    }

    [Fact]
    public void TotalCount_WhenAllEmpty_IsZero()
    {
        var results = new SearchResults();

        results.TotalCount.Should().Be(0);
    }

    [Fact]
    public void TotalCount_SumsAllCollections()
    {
        var results = new SearchResults
        {
            Channels = [new SearchResultItem { ContentId = 1, Title = "Ch1" }],
            Movies = [new SearchResultItem { ContentId = 2, Title = "Mv1" }, new SearchResultItem { ContentId = 3, Title = "Mv2" }],
            Series = [new SearchResultItem { ContentId = 4, Title = "Sr1" }],
        };

        results.TotalCount.Should().Be(4);
    }

    [Fact]
    public void TotalCount_OnlyChannels_CountsCorrectly()
    {
        var results = new SearchResults
        {
            Channels =
            [
                new SearchResultItem { ContentId = 1, Title = "A" },
                new SearchResultItem { ContentId = 2, Title = "B" },
            ],
        };

        results.TotalCount.Should().Be(2);
    }

    [Fact]
    public void Channels_CanBeSet()
    {
        var item = new SearchResultItem { ContentId = 10, Title = "News" };
        var results = new SearchResults { Channels = [item] };

        results.Channels.Should().ContainSingle().Which.Should().Be(item);
    }

    [Fact]
    public void Movies_CanBeSet()
    {
        var item = new SearchResultItem { ContentId = 20, Title = "Action" };
        var results = new SearchResults { Movies = [item] };

        results.Movies.Should().ContainSingle().Which.Should().Be(item);
    }

    [Fact]
    public void Series_CanBeSet()
    {
        var item = new SearchResultItem { ContentId = 30, Title = "Drama" };
        var results = new SearchResults { Series = [item] };

        results.Series.Should().ContainSingle().Which.Should().Be(item);
    }
}

[Trait("Category", "Unit")]
public class SearchResultItemTests
{
    [Fact]
    public void Constructor_RequiredProperties_SetCorrectly()
    {
        var item = new SearchResultItem { ContentId = 99, Title = "Test Channel" };

        item.ContentId.Should().Be(99);
        item.Title.Should().Be("Test Channel");
    }

    [Fact]
    public void Thumbnail_DefaultsToNull()
    {
        var item = new SearchResultItem { ContentId = 1, Title = "X" };

        item.Thumbnail.Should().BeNull();
    }

    [Fact]
    public void Rank_DefaultsToZero()
    {
        var item = new SearchResultItem { ContentId = 1, Title = "X" };

        item.Rank.Should().Be(0.0);
    }

    [Fact]
    public void Thumbnail_CanBeSet()
    {
        var item = new SearchResultItem
        {
            ContentId = 1,
            Title = "X",
            Thumbnail = "http://thumb.test/img.jpg",
        };

        item.Thumbnail.Should().Be("http://thumb.test/img.jpg");
    }

    [Fact]
    public void Rank_CanBeSet()
    {
        var item = new SearchResultItem
        {
            ContentId = 1,
            Title = "X",
            Rank = -12.5,
        };

        item.Rank.Should().Be(-12.5);
    }

    [Fact]
    public void AllProperties_CanBeSetTogether()
    {
        var item = new SearchResultItem
        {
            ContentId = 42,
            Title = "Full Item",
            Thumbnail = "http://img.test/thumb.png",
            Rank = -3.14,
        };

        item.ContentId.Should().Be(42);
        item.Title.Should().Be("Full Item");
        item.Thumbnail.Should().Be("http://img.test/thumb.png");
        item.Rank.Should().BeApproximately(-3.14, 0.0001);
    }
}
