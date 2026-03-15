using Crispy.Application.Search;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;
using NSubstitute.ExceptionExtensions;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class SearchViewModelTests
{
    private readonly ISearchService _searchService;
    private readonly SearchViewModel _sut;

    private static SearchResults EmptyResults() => new();

    private static SearchResults ResultsWith(
        IReadOnlyList<SearchResultItem>? channels = null,
        IReadOnlyList<SearchResultItem>? movies = null,
        IReadOnlyList<SearchResultItem>? series = null) => new()
        {
            Channels = channels ?? [],
            Movies = movies ?? [],
            Series = series ?? [],
        };

    private static SearchResultItem Item(int id, string title) => new()
    {
        ContentId = id,
        Title = title,
    };

    public SearchViewModelTests()
    {
        _searchService = Substitute.For<ISearchService>();
        _searchService
            .SearchAsync(Arg.Any<string>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(EmptyResults());

        _sut = new SearchViewModel(_searchService);
    }

    // ── Default state ──────────────────────────────────────────────────────────

    [Fact]
    public void Title_IsSearch()
    {
        _sut.Title.Should().Be("Search");
    }

    [Fact]
    public void SearchQuery_DefaultsToEmpty()
    {
        _sut.SearchQuery.Should().BeEmpty();
    }

    [Fact]
    public void ChannelResults_DefaultsToEmpty()
    {
        _sut.ChannelResults.Should().BeEmpty();
    }

    [Fact]
    public void MovieResults_DefaultsToEmpty()
    {
        _sut.MovieResults.Should().BeEmpty();
    }

    [Fact]
    public void SeriesResults_DefaultsToEmpty()
    {
        _sut.SeriesResults.Should().BeEmpty();
    }

    [Fact]
    public void IsSearching_DefaultsFalse()
    {
        _sut.IsSearching.Should().BeFalse();
    }

    [Fact]
    public void HasResults_DefaultsFalse()
    {
        _sut.HasResults.Should().BeFalse();
    }

    [Fact]
    public void ErrorMessage_DefaultsNull()
    {
        _sut.ErrorMessage.Should().BeNull();
    }

    // ── Empty / whitespace query clears results without calling service ────────

    [Fact]
    public async Task SearchQuery_SetToWhitespace_DoesNotCallService()
    {
        _sut.SearchQuery = "   ";

        // Give the fire-and-forget task time to complete.
        await Task.Delay(50);

        await _searchService
            .DidNotReceive()
            .SearchAsync(Arg.Any<string>(), Arg.Any<int>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SearchQuery_SetToEmpty_ClearsCollections()
    {
        // Pre-populate via a real search first.
        _searchService
            .SearchAsync("cat", 1, Arg.Any<CancellationToken>())
            .Returns(ResultsWith(channels: [Item(1, "Cat TV")]));

        _sut.SearchQuery = "cat";
        await Task.Delay(300); // past the 150ms debounce

        // Now clear.
        _sut.SearchQuery = string.Empty;
        await Task.Delay(50);

        _sut.ChannelResults.Should().BeEmpty();
        _sut.MovieResults.Should().BeEmpty();
        _sut.SeriesResults.Should().BeEmpty();
        _sut.HasResults.Should().BeFalse();
        _sut.IsSearching.Should().BeFalse();
        _sut.ErrorMessage.Should().BeNull();
    }

    // ── Successful search populates collections ───────────────────────────────

    [Fact]
    public async Task SearchQuery_NonEmpty_CallsServiceAfterDebounce()
    {
        _sut.SearchQuery = "news";
        await Task.Delay(300);

        await _searchService
            .Received(1)
            .SearchAsync("news", 1, Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SearchAsync_PopulatesChannelResults()
    {
        _searchService
            .SearchAsync("sport", 1, Arg.Any<CancellationToken>())
            .Returns(ResultsWith(channels: [Item(10, "Sport Channel")]));

        _sut.SearchQuery = "sport";
        await Task.Delay(300);

        _sut.ChannelResults.Should().ContainSingle(r => r.Title == "Sport Channel");
    }

    [Fact]
    public async Task SearchAsync_PopulatesMovieResults()
    {
        _searchService
            .SearchAsync("inception", 1, Arg.Any<CancellationToken>())
            .Returns(ResultsWith(movies: [Item(20, "Inception")]));

        _sut.SearchQuery = "inception";
        await Task.Delay(300);

        _sut.MovieResults.Should().ContainSingle(r => r.Title == "Inception");
    }

    [Fact]
    public async Task SearchAsync_PopulatesSeriesResults()
    {
        _searchService
            .SearchAsync("breaking", 1, Arg.Any<CancellationToken>())
            .Returns(ResultsWith(series: [Item(30, "Breaking Bad")]));

        _sut.SearchQuery = "breaking";
        await Task.Delay(300);

        _sut.SeriesResults.Should().ContainSingle(r => r.Title == "Breaking Bad");
    }

    [Fact]
    public async Task SearchAsync_SetsHasResultsTrue_WhenAnyResultExists()
    {
        _searchService
            .SearchAsync("fox", 1, Arg.Any<CancellationToken>())
            .Returns(ResultsWith(channels: [Item(5, "Fox News")]));

        _sut.SearchQuery = "fox";
        await Task.Delay(300);

        _sut.HasResults.Should().BeTrue();
    }

    [Fact]
    public async Task SearchAsync_SetsHasResultsFalse_WhenNoResults()
    {
        _searchService
            .SearchAsync("zzz", 1, Arg.Any<CancellationToken>())
            .Returns(EmptyResults());

        _sut.SearchQuery = "zzz";
        await Task.Delay(300);

        _sut.HasResults.Should().BeFalse();
    }

    [Fact]
    public async Task SearchAsync_IsSearchingFalse_AfterCompletion()
    {
        _sut.SearchQuery = "done";
        await Task.Delay(300);

        _sut.IsSearching.Should().BeFalse();
    }

    // ── Debounce — rapid typing only fires one request ────────────────────────

    [Fact]
    public async Task RapidQueryChanges_OnlyLastQueryReachesService()
    {
        _sut.SearchQuery = "a";
        _sut.SearchQuery = "ab";
        _sut.SearchQuery = "abc";

        await Task.Delay(300);

        await _searchService
            .Received(1)
            .SearchAsync("abc", 1, Arg.Any<CancellationToken>());
    }

    // ── Error handling ────────────────────────────────────────────────────────

    [Fact]
    public async Task SearchAsync_SetsErrorMessage_WhenServiceThrows()
    {
        _searchService
            .SearchAsync("fail", 1, Arg.Any<CancellationToken>())
            .ThrowsAsync(new InvalidOperationException("DB offline"));

        _sut.SearchQuery = "fail";
        await Task.Delay(300);

        _sut.ErrorMessage.Should().Contain("DB offline");
        _sut.IsSearching.Should().BeFalse();
    }

    [Fact]
    public async Task SearchAsync_ClearsErrorMessage_OnSuccessfulRetry()
    {
        _searchService
            .SearchAsync("fail", 1, Arg.Any<CancellationToken>())
            .ThrowsAsync(new InvalidOperationException("oops"));

        _sut.SearchQuery = "fail";
        await Task.Delay(300);

        _sut.ErrorMessage.Should().NotBeNull();

        _searchService
            .SearchAsync("ok", 1, Arg.Any<CancellationToken>())
            .Returns(EmptyResults());

        _sut.SearchQuery = "ok";
        await Task.Delay(300);

        _sut.ErrorMessage.Should().BeNull();
    }
}
