using System.Text;

using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.M3U;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers.M3U;

[Trait("Category", "Unit")]
public class M3UParserTests
{
    // ─── Helpers ───────────────────────────────────────────────────────────────

    private static Stream ToStream(string content)
        => new MemoryStream(Encoding.UTF8.GetBytes(content));

    private static async Task<List<M3UEntry>> ParseAsync(string content, CancellationToken ct = default)
    {
        var parser = new M3UParser();
        var entries = new List<M3UEntry>();
        await foreach (var entry in parser.ParseStreamAsync(ToStream(content), ct))
            entries.Add(entry);
        return entries;
    }

    // ─── Basic valid M3U ───────────────────────────────────────────────────────

    [Fact]
    public async Task ParseStreamAsync_ReturnsSingleEntry_WhenValidMinimalM3U()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,News Channel
            http://stream.example.com/news
            """;

        var entries = await ParseAsync(m3u);

        entries.Should().HaveCount(1);
        entries[0].Title.Should().Be("News Channel");
        entries[0].Url.Should().Be("http://stream.example.com/news");
    }

    [Fact]
    public async Task ParseStreamAsync_ReturnsMultipleEntries_WhenMultipleChannels()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,Channel One
            http://stream.example.com/ch1
            #EXTINF:-1,Channel Two
            http://stream.example.com/ch2
            #EXTINF:-1,Channel Three
            http://stream.example.com/ch3
            """;

        var entries = await ParseAsync(m3u);

        entries.Should().HaveCount(3);
        entries.Select(e => e.Title).Should().ContainInOrder("Channel One", "Channel Two", "Channel Three");
    }

    // ─── Attribute parsing ─────────────────────────────────────────────────────

    [Fact]
    public async Task ParseStreamAsync_ParsesTvgAttributes_WhenQuotedValues()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-id="sports.hd" tvg-name="Sports HD" tvg-logo="http://logo.example.com/sports.png" group-title="Sports",Sports HD
            http://stream.example.com/sports
            """;

        var entries = await ParseAsync(m3u);

        entries.Should().HaveCount(1);
        var e = entries[0];
        e.TvgId.Should().Be("sports.hd");
        e.TvgName.Should().Be("Sports HD");
        e.TvgLogo.Should().Be("http://logo.example.com/sports.png");
        e.GroupTitle.Should().Be("Sports");
    }

    [Fact]
    public async Task ParseStreamAsync_ParsesTvgChno_WhenPresentAsInteger()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-chno="42",Channel 42
            http://stream.example.com/ch42
            """;

        var entries = await ParseAsync(m3u);

        entries[0].TvgChno.Should().Be(42);
    }

    [Fact]
    public async Task ParseStreamAsync_LeavesTvgChnoNull_WhenAttributeAbsent()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,No Chno Channel
            http://stream.example.com/nochno
            """;

        var entries = await ParseAsync(m3u);

        entries[0].TvgChno.Should().BeNull();
    }

    [Fact]
    public async Task ParseStreamAsync_SetsIsRadioTrue_WhenRadioAttributeIsOne()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 radio="1",Radio Station
            http://stream.example.com/radio
            """;

        var entries = await ParseAsync(m3u);

        entries[0].IsRadio.Should().BeTrue();
    }

    [Fact]
    public async Task ParseStreamAsync_SetsIsRadioTrue_WhenRadioAttributeIsTrue()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 radio="true",Radio Station
            http://stream.example.com/radio
            """;

        var entries = await ParseAsync(m3u);

        entries[0].IsRadio.Should().BeTrue();
    }

    [Fact]
    public async Task ParseStreamAsync_SetsIsRadioFalse_WhenRadioAttributeAbsent()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,TV Channel
            http://stream.example.com/tv
            """;

        var entries = await ParseAsync(m3u);

        entries[0].IsRadio.Should().BeFalse();
    }

    // ─── Catchup attributes ────────────────────────────────────────────────────

    [Fact]
    public async Task ParseStreamAsync_SetsCatchupTypeDefault_WhenCatchupIsDefault()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 catchup="default" catchup-days="7" catchup-source="http://catchup.example.com/{start}/{end}",Catchup Channel
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        var e = entries[0];
        e.CatchupType.Should().Be(CatchupType.Default);
        e.CatchupDays.Should().Be(7);
        e.CatchupSource.Should().Be("http://catchup.example.com/{start}/{end}");
    }

    [Fact]
    public async Task ParseStreamAsync_SetsCatchupTypeAppend_WhenCatchupIsAppend()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 catchup="append",Append Channel
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].CatchupType.Should().Be(CatchupType.Append);
    }

    [Fact]
    public async Task ParseStreamAsync_SetsCatchupTypeFlussonic_WhenCatchupIsFlussonic()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 catchup="flussonic",Flussonic Channel
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].CatchupType.Should().Be(CatchupType.Flussonic);
    }

    [Fact]
    public async Task ParseStreamAsync_SetsCatchupTypeShift_WhenCatchupIsShift()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 catchup="shift",Shift Channel
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].CatchupType.Should().Be(CatchupType.Shift);
    }

    [Fact]
    public async Task ParseStreamAsync_SetsCatchupTypeXc_WhenCatchupIsXc()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 catchup="xc",XC Channel
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].CatchupType.Should().Be(CatchupType.Xc);
    }

    [Fact]
    public async Task ParseStreamAsync_SetsCatchupTypeNone_WhenCatchupValueUnknown()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 catchup="bogus",No Catchup Channel
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].CatchupType.Should().Be(CatchupType.None);
    }

    [Fact]
    public async Task ParseStreamAsync_SetsCatchupDaysZero_WhenAttributeAbsent()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,No Days Channel
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].CatchupDays.Should().Be(0);
    }

    // ─── EXTVLCOPT / KODIPROP headers ─────────────────────────────────────────

    [Fact]
    public async Task ParseStreamAsync_SetsHttpUserAgent_WhenExtvlcoptUserAgentPresent()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,UA Channel
            #EXTVLCOPT:http-user-agent=CustomAgent/1.0
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].HttpUserAgent.Should().Be("CustomAgent/1.0");
    }

    [Fact]
    public async Task ParseStreamAsync_SetsHttpReferrer_WhenExtvlcoptReferrerPresent()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,Ref Channel
            #EXTVLCOPT:http-referrer=http://referrer.example.com
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].HttpReferrer.Should().Be("http://referrer.example.com");
    }

    [Fact]
    public async Task ParseStreamAsync_SetsKodiStreamHeaders_WhenKodipropPresent()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,Kodi Channel
            KODIPROP:inputstream.adaptive.stream_headers=Referer=http://ref.example.com
            http://stream.example.com/live
            """;

        var entries = await ParseAsync(m3u);

        entries[0].KodiStreamHeaders.Should().Be("Referer=http://ref.example.com");
    }

    // ─── Empty / malformed input ───────────────────────────────────────────────

    [Fact]
    public async Task ParseStreamAsync_ReturnsEmpty_WhenStreamIsEmpty()
    {
        var entries = await ParseAsync(string.Empty);

        entries.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseStreamAsync_ReturnsEmpty_WhenOnlyExtm3uHeader()
    {
        const string m3u = "#EXTM3U";

        var entries = await ParseAsync(m3u);

        entries.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseStreamAsync_SkipsEntry_WhenExtinfHasNoComma()
    {
        // #EXTINF line without comma: TryParseStrict returns null, ParseLenient uses URL as title
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-id="no-comma-id"
            http://stream.example.com/no-comma
            """;

        var entries = await ParseAsync(m3u);

        // Lenient parser uses URL as title when no comma is present
        entries.Should().HaveCount(1);
        entries[0].Url.Should().Be("http://stream.example.com/no-comma");
    }

    [Fact]
    public async Task ParseStreamAsync_SkipsUrlLine_WhenNoExtinfPrecedes()
    {
        const string m3u = """
            #EXTM3U
            http://stream.example.com/orphan-url
            """;

        var entries = await ParseAsync(m3u);

        entries.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseStreamAsync_SkipsCommentLines_WhenNonDirectiveHashLines()
    {
        const string m3u = """
            #EXTM3U
            # This is a comment
            #EXTINF:-1,Valid Channel
            http://stream.example.com/valid
            """;

        var entries = await ParseAsync(m3u);

        entries.Should().HaveCount(1);
        entries[0].Title.Should().Be("Valid Channel");
    }

    [Fact]
    public async Task ParseStreamAsync_FallsBackToLenient_WhenExtinfHasUnclosedQuote()
    {
        // Unclosed quote: strict regex rejects the line, lenient path takes over
        const string m3u = "#EXTM3U\n#EXTINF:-1 group-title=\"Sports HD,Sports HD\nhttp://stream.example.com/sports\n";

        var entries = await ParseAsync(m3u);

        entries.Should().HaveCount(1);
        entries[0].Title.Should().Be("Sports HD");
        entries[0].IsLenientParsed.Should().BeTrue();
    }

    [Fact]
    public async Task ParseStreamAsync_SetsNullGroupTitle_WhenGroupTitleIsEmpty()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 group-title="",Empty Group Channel
            http://stream.example.com/empty-group
            """;

        var entries = await ParseAsync(m3u);

        entries[0].GroupTitle.Should().BeNull();
    }

    [Fact]
    public async Task ParseStreamAsync_IsNotLenientParsed_WhenStrictParsingSucceeds()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-id="test.id" group-title="News",News Channel
            http://stream.example.com/news
            """;

        var entries = await ParseAsync(m3u);

        entries[0].IsLenientParsed.Should().BeFalse();
    }

    [Fact]
    public async Task ParseStreamAsync_CancelledToken_ThrowsOperationCancelledException()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1,Channel
            http://stream.example.com/live
            """;

        var cts = new CancellationTokenSource();
        cts.Cancel();

        Func<Task> act = async () => await ParseAsync(m3u, cts.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
    }

    // ─── Unquoted attribute values ─────────────────────────────────────────────

    [Fact]
    public async Task ParseStreamAsync_ParsesUnquotedAttributeValues_WhenNoSpacesInValues()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-id=unquoted.id tvg-chno=5,Unquoted Channel
            http://stream.example.com/unquoted
            """;

        var entries = await ParseAsync(m3u);

        entries.Should().HaveCount(1);
        entries[0].TvgId.Should().Be("unquoted.id");
        entries[0].TvgChno.Should().Be(5);
    }
}
