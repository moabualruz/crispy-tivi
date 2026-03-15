using Crispy.Application.Sources;
using Crispy.Domain.Entities;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Sources;

[Trait("Category", "Unit")]
public sealed class ParseResultTests
{
    [Fact]
    public void ParseResult_DefaultConstruction_HasEmptyListsAndNullError()
    {
        var result = new ParseResult();

        result.Channels.Should().NotBeNull().And.BeEmpty();
        result.Movies.Should().NotBeNull().And.BeEmpty();
        result.Series.Should().NotBeNull().And.BeEmpty();
        result.SkippedCount.Should().Be(0);
        result.Error.Should().BeNull();
    }

    [Fact]
    public void ParseResult_IsSuccess_ReturnsTrueByDefault()
    {
        var result = new ParseResult();

        result.IsSuccess.Should().BeTrue();
    }

    [Fact]
    public void ParseResult_IsSuccess_ReturnsFalse_WhenErrorIsSet()
    {
        var result = new ParseResult { Error = "Parse failed: unexpected EOF" };

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Parse failed: unexpected EOF");
    }

    [Fact]
    public void ParseResult_StoresChannels_WhenProvided()
    {
        var channels = new List<Channel>
        {
            new() { Title = "BBC One", SourceId = 1 },
            new() { Title = "CNN", SourceId = 1 },
        };

        var result = new ParseResult { Channels = channels };

        result.Channels.Should().HaveCount(2);
        result.Channels[0].Title.Should().Be("BBC One");
    }

    [Fact]
    public void ParseResult_StoresMovies_WhenProvided()
    {
        var movies = new List<Movie>
        {
            new() { Title = "Inception", SourceId = 1 },
        };

        var result = new ParseResult { Movies = movies };

        result.Movies.Should().ContainSingle();
        result.Movies[0].Title.Should().Be("Inception");
    }

    [Fact]
    public void ParseResult_StoresSeries_WhenProvided()
    {
        var series = new List<Series>
        {
            new() { Title = "Breaking Bad", SourceId = 1 },
        };

        var result = new ParseResult { Series = series };

        result.Series.Should().ContainSingle();
        result.Series[0].Title.Should().Be("Breaking Bad");
    }

    [Fact]
    public void ParseResult_StoresSkippedCount()
    {
        var result = new ParseResult { SkippedCount = 17 };

        result.SkippedCount.Should().Be(17);
    }

    [Fact]
    public void ParseResult_IsSuccess_ReturnsFalse_WhenErrorIsEmptyString()
    {
        // Empty string is NOT null — IsSuccess checks Error is null
        var result = new ParseResult { Error = string.Empty };

        result.IsSuccess.Should().BeFalse();
    }
}
