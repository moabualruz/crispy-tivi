using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.M3U;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers.M3U;

[Trait("Category", "Unit")]
public class M3UEntryTests
{
    [Fact]
    public void Constructor_SetsRequiredProperties_WhenMinimalValuesProvided()
    {
        var entry = new M3UEntry { Url = "http://example.com/stream", Title = "Test Channel" };

        entry.Url.Should().Be("http://example.com/stream");
        entry.Title.Should().Be("Test Channel");
    }

    [Fact]
    public void CatchupType_DefaultsToNone_WhenNotSet()
    {
        var entry = new M3UEntry { Url = "http://example.com/stream", Title = "Test" };

        entry.CatchupType.Should().Be(CatchupType.None);
    }

    [Fact]
    public void CatchupDays_DefaultsToZero_WhenNotSet()
    {
        var entry = new M3UEntry { Url = "http://example.com/stream", Title = "Test" };

        entry.CatchupDays.Should().Be(0);
    }

    [Fact]
    public void IsRadio_DefaultsFalse_WhenNotSet()
    {
        var entry = new M3UEntry { Url = "http://example.com/stream", Title = "Test" };

        entry.IsRadio.Should().BeFalse();
    }

    [Fact]
    public void IsLenientParsed_DefaultsFalse_WhenNotSet()
    {
        var entry = new M3UEntry { Url = "http://example.com/stream", Title = "Test" };

        entry.IsLenientParsed.Should().BeFalse();
    }

    [Fact]
    public void OptionalStringProperties_DefaultToNull_WhenNotSet()
    {
        var entry = new M3UEntry { Url = "http://example.com/stream", Title = "Test" };

        entry.TvgId.Should().BeNull();
        entry.TvgName.Should().BeNull();
        entry.TvgLogo.Should().BeNull();
        entry.TvgChno.Should().BeNull();
        entry.GroupTitle.Should().BeNull();
        entry.CatchupSource.Should().BeNull();
        entry.HttpUserAgent.Should().BeNull();
        entry.HttpReferrer.Should().BeNull();
        entry.KodiStreamHeaders.Should().BeNull();
    }

    [Fact]
    public void AllProperties_RoundTrip_WhenFullyPopulated()
    {
        var entry = new M3UEntry
        {
            Url = "http://stream.example.com/live/ch1.m3u8",
            Title = "Sports HD",
            TvgId = "sports.hd",
            TvgName = "Sports HD",
            TvgLogo = "http://logo.example.com/sports.png",
            TvgChno = 101,
            GroupTitle = "Sports",
            IsRadio = true,
            CatchupType = CatchupType.Append,
            CatchupSource = "http://catchup.example.com/{start}/{end}",
            CatchupDays = 7,
            HttpUserAgent = "VLC/3.0",
            HttpReferrer = "http://referrer.example.com",
            KodiStreamHeaders = "Referer=http://referrer.example.com",
            IsLenientParsed = true,
        };

        entry.Url.Should().Be("http://stream.example.com/live/ch1.m3u8");
        entry.Title.Should().Be("Sports HD");
        entry.TvgId.Should().Be("sports.hd");
        entry.TvgName.Should().Be("Sports HD");
        entry.TvgLogo.Should().Be("http://logo.example.com/sports.png");
        entry.TvgChno.Should().Be(101);
        entry.GroupTitle.Should().Be("Sports");
        entry.IsRadio.Should().BeTrue();
        entry.CatchupType.Should().Be(CatchupType.Append);
        entry.CatchupSource.Should().Be("http://catchup.example.com/{start}/{end}");
        entry.CatchupDays.Should().Be(7);
        entry.HttpUserAgent.Should().Be("VLC/3.0");
        entry.HttpReferrer.Should().Be("http://referrer.example.com");
        entry.KodiStreamHeaders.Should().Be("Referer=http://referrer.example.com");
        entry.IsLenientParsed.Should().BeTrue();
    }
}
