using Crispy.UI.Navigation;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Navigation;

/// <summary>
/// Tests for crispy:// deep link URI parser.
/// </summary>
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
}
