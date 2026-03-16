using Crispy.UI.Navigation;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Navigation;

/// <summary>
/// Tests for crispy:// deep link URI parser.
/// </summary>
[Trait("Category", "Unit")]
public class DeepLinkParserTests
{
    [Fact]
    public void Parse_LiveChannel_ReturnsCorrectResult()
    {
        var result = DeepLinkParser.Parse("crispy://live/channel/123");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("LiveTv");
        result.Id.Should().Be("123");
    }

    [Fact]
    public void Parse_VodMovie_ReturnsCorrectResult()
    {
        var result = DeepLinkParser.Parse("crispy://vod/movie/456");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Movies");
        result.Id.Should().Be("456");
    }

    [Fact]
    public void Parse_VodSeries_ReturnsCorrectResult()
    {
        var result = DeepLinkParser.Parse("crispy://vod/series/789");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Series");
        result.Id.Should().Be("789");
    }

    [Fact]
    public void Parse_Settings_ReturnsNoId()
    {
        var result = DeepLinkParser.Parse("crispy://settings");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Settings");
        result.Id.Should().BeNull();
    }

    [Fact]
    public void Parse_SettingsWithCategory_ReturnsCategory()
    {
        var result = DeepLinkParser.Parse("crispy://settings/playback");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Settings");
        result.Id.Should().Be("playback");
    }

    [Fact]
    public void Parse_SearchWithQuery_ReturnsQueryParams()
    {
        var result = DeepLinkParser.Parse("crispy://search?q=action");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Search");
        result.Query.Should().ContainKey("q").WhoseValue.Should().Be("action");
    }

    [Fact]
    public void Parse_InvalidUri_ReturnsNull()
    {
        var result = DeepLinkParser.Parse("invalid");

        result.Should().BeNull();
    }

    [Fact]
    public void Parse_Null_ReturnsNull()
    {
        var result = DeepLinkParser.Parse(null);

        result.Should().BeNull();
    }

    [Fact]
    public void Parse_EmptyString_ReturnsNull()
    {
        var result = DeepLinkParser.Parse("");

        result.Should().BeNull();
    }

    [Fact]
    public void Parse_WrongScheme_ReturnsNull()
    {
        var result = DeepLinkParser.Parse("https://live/channel/1");

        result.Should().BeNull();
    }

    [Fact]
    public void Parse_WhitespaceOnly_ReturnsNull()
    {
        var result = DeepLinkParser.Parse("   ");

        result.Should().BeNull();
    }

    [Fact]
    public void Parse_Home_ReturnsHomeScreen()
    {
        var result = DeepLinkParser.Parse("crispy://home");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Home");
        result.Id.Should().BeNull();
    }

    [Fact]
    public void Parse_LiveChannelWithoutId_ReturnsNullId()
    {
        var result = DeepLinkParser.Parse("crispy://live/channel");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("LiveTv");
        result.Id.Should().BeNull();
    }

    [Fact]
    public void Parse_VodMovieWithoutId_ReturnsNullId()
    {
        var result = DeepLinkParser.Parse("crispy://vod/movie");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Movies");
        result.Id.Should().BeNull();
    }

    [Fact]
    public void Parse_VodSeriesWithoutId_ReturnsNullId()
    {
        var result = DeepLinkParser.Parse("crispy://vod/series");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Series");
        result.Id.Should().BeNull();
    }

    [Fact]
    public void Parse_SearchWithNoQuery_ReturnsNullQuery()
    {
        var result = DeepLinkParser.Parse("crispy://search");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Search");
        result.Query.Should().BeNull();
    }

    [Fact]
    public void Parse_UnrecognizedRoute_ReturnsNull()
    {
        var result = DeepLinkParser.Parse("crispy://unknown/route");

        result.Should().BeNull();
    }

    [Fact]
    public void DeepLinkResult_RecordEquality_TwoIdenticalResults_AreEqual()
    {
        var a = new DeepLinkResult("Home", null, null);
        var b = new DeepLinkResult("Home", null, null);

        a.Should().Be(b);
    }

    [Fact]
    public void Parse_SearchWithMultipleQueryParams_ReturnsAllParams()
    {
        var result = DeepLinkParser.Parse("crispy://search?q=action&lang=en");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Search");
        result.Query.Should().ContainKey("q").WhoseValue.Should().Be("action");
        result.Query.Should().ContainKey("lang").WhoseValue.Should().Be("en");
    }

    [Fact]
    public void Parse_QueryKeyWithNoValue_ReturnsEmptyStringValue()
    {
        // "flag" has no '=' — ParseQuery should store empty string
        var result = DeepLinkParser.Parse("crispy://search?flag");

        result.Should().NotBeNull();
        result!.Query.Should().ContainKey("flag").WhoseValue.Should().BeEmpty();
    }

    [Fact]
    public void Parse_QueryParamWithEncodedValue_DecodesCorrectly()
    {
        var result = DeepLinkParser.Parse("crispy://search?q=action%20movie");

        result.Should().NotBeNull();
        result!.Query!["q"].Should().Be("action movie");
    }

    [Fact]
    public void Parse_SettingsWithQueryParams_ReturnsQueryAndId()
    {
        var result = DeepLinkParser.Parse("crispy://settings/playback?autoplay=true");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Settings");
        result.Id.Should().Be("playback");
        result.Query.Should().ContainKey("autoplay");
    }

    [Fact]
    public void Parse_VodSeriesWithQueryParams_ReturnsSeriesScreenAndQuery()
    {
        var result = DeepLinkParser.Parse("crispy://vod/series/42?season=2");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Series");
        result.Id.Should().Be("42");
        result.Query.Should().ContainKey("season").WhoseValue.Should().Be("2");
    }

    [Fact]
    public void Parse_HomeWithQuery_ReturnsHomeScreenWithQuery()
    {
        var result = DeepLinkParser.Parse("crispy://home?featured=true");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Home");
        result.Query.Should().ContainKey("featured");
    }

    [Fact]
    public void DeepLinkResult_Deconstruct_ScreenIdQuery()
    {
        var r = new DeepLinkResult("LiveTv", "5", null);

        r.Screen.Should().Be("LiveTv");
        r.Id.Should().Be("5");
        r.Query.Should().BeNull();
    }

    [Fact]
    public void Parse_QueryStringIsOnlyQuestionMark_ReturnsNullQuery()
    {
        // ParseQuery receives "?" which after TrimStart('?') becomes "" → returns null
        var result = DeepLinkParser.Parse("crispy://search?");

        result.Should().NotBeNull();
        result!.Screen.Should().Be("Search");
        result.Query.Should().BeNull();
    }

    [Fact]
    public void Parse_UriWithEmptyHostAndNoPath_ReturnsNull()
    {
        // crispy:/// → Host="" Path="/" → allSegments empty → returns null
        var result = DeepLinkParser.Parse("crispy:///");

        result.Should().BeNull();
    }

    [Fact]
    public void Parse_VodWithUnknownSubRoute_ReturnsNull()
    {
        // "vod/episode" matches neither "movie" nor "series" → falls through to null
        var result = DeepLinkParser.Parse("crispy://vod/episode/5");

        result.Should().BeNull();
    }
}
