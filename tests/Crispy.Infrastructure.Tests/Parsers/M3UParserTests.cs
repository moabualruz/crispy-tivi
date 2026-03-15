using System.Text;

using Crispy.Infrastructure.Parsers.M3U;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

[Trait("Category", "Unit")]
public class M3UParserTests
{
    private static Stream MakeStream(string content, Encoding? encoding = null)
    {
        encoding ??= Encoding.UTF8;
        return new MemoryStream(encoding.GetBytes(content));
    }

    private static Stream MakeStreamWithBom(string content)
    {
        // UTF-8 BOM
        var bom = new byte[] { 0xEF, 0xBB, 0xBF };
        var body = Encoding.UTF8.GetBytes(content);
        var combined = bom.Concat(body).ToArray();
        return new MemoryStream(combined);
    }

    [Fact]
    public async Task ParseStreamAsync_SampleFile_ReturnsAllSevenEntries()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Fixtures", "sample.m3u");
        await using var stream = File.OpenRead(path);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var entry in parser.ParseStreamAsync(stream))
            entries.Add(entry);

        entries.Should().HaveCount(7, "5 valid + 2 malformed entries, all parsed");
    }

    [Fact]
    public async Task ParseStreamAsync_ExtractsAttributes_Correctly()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-id="bbc1.uk" tvg-name="BBC One" tvg-logo="https://logo.png" tvg-chno="1" group-title="News" catchup="default" catchup-source="https://cu.com/{start}" catchup-days="7",BBC One HD
            https://stream.example.com/bbc1.m3u8
            """;

        using var stream = MakeStream(m3u);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().HaveCount(1);
        var entry = entries[0];
        entry.TvgId.Should().Be("bbc1.uk");
        entry.TvgName.Should().Be("BBC One");
        entry.TvgLogo.Should().Be("https://logo.png");
        entry.TvgChno.Should().Be(1);
        entry.GroupTitle.Should().Be("News");
        entry.CatchupType.Should().Be(Crispy.Domain.Enums.CatchupType.Default);
        entry.CatchupSource.Should().Be("https://cu.com/{start}");
        entry.CatchupDays.Should().Be(7);
        entry.Title.Should().Be("BBC One HD");
        entry.Url.Should().Be("https://stream.example.com/bbc1.m3u8");
    }

    [Fact]
    public async Task ParseStreamAsync_BomAtStart_DoesNotCorruptFirstEntry()
    {
        const string body = """
            #EXTM3U
            #EXTINF:-1 tvg-id="bomtest" tvg-name="BOM Test",BOM Channel
            https://stream.example.com/bom.m3u8
            """;

        using var stream = MakeStreamWithBom(body);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().HaveCount(1);
        entries[0].TvgId.Should().Be("bomtest");
    }

    [Fact]
    public async Task ParseStreamAsync_RadioChannel_IsRadioTrue()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-id="r4" tvg-name="Radio 4" radio=1,Radio Four
            https://stream.example.com/r4.mp3
            """;

        using var stream = MakeStream(m3u);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().HaveCount(1);
        entries[0].IsRadio.Should().BeTrue();
    }

    [Fact]
    public async Task ParseStreamAsync_VlcOptHeaders_Extracted()
    {
        const string m3u = "#EXTM3U\r\n" +
            "#EXTINF:-1 tvg-id=\"cnn\" tvg-name=\"CNN\",CNN\r\n" +
            "#EXTVLCOPT:http-user-agent=TestUA\r\n" +
            "#EXTVLCOPT:http-referrer=https://ref.example.com/\r\n" +
            "https://stream.example.com/cnn.ts\r\n";

        using var stream = MakeStream(m3u);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().HaveCount(1);
        entries[0].HttpUserAgent.Should().Be("TestUA");
        entries[0].HttpReferrer.Should().Be("https://ref.example.com/");
    }

    [Fact]
    public async Task ParseStreamAsync_MalformedEntries_ParsedViaLenientPath()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-name="Valid Channel" tvg-id="v1",Valid Channel
            https://stream.example.com/v1.ts
            #EXTINF:-1 tvg-name="Broken No Quotes tvg-logo=noquotes.png group-title=Broken,Malformed 1
            https://stream.example.com/broken1.ts
            """;

        using var stream = MakeStream(m3u);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().HaveCount(2, "malformed entry should be returned via lenient path, not dropped");
        entries[1].Title.Should().Be("Malformed 1");
        entries[1].IsLenientParsed.Should().BeTrue();
    }

    // ------------------------------------------------------------------
    // Empty stream → yields nothing
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseStreamAsync_YieldsNothing_WhenStreamIsEmpty()
    {
        using var stream = MakeStream(string.Empty);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().BeEmpty();
    }

    // ------------------------------------------------------------------
    // EXTINF without URL (no subsequent URL line) → not yielded
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseStreamAsync_SkipsExtinf_WhenNoUrlFollows()
    {
        const string m3u = """
            #EXTM3U
            #EXTINF:-1 tvg-id="nourl",No URL Channel
            """;

        using var stream = MakeStream(m3u);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().BeEmpty();
    }

    // ------------------------------------------------------------------
    // Cancellation mid-stream
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseStreamAsync_ThrowsOperationCanceledException_WhenCancelled()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        var parser = new M3UParser();
        using var stream = MakeStream("#EXTM3U\n#EXTINF:-1,Ch\nhttps://s.example.com/1.ts\n");

        var act = async () =>
        {
            await foreach (var _ in parser.ParseStreamAsync(stream, cts.Token))
            {
                // consume
            }
        };

        await act.Should().ThrowAsync<OperationCanceledException>();
    }

    // ------------------------------------------------------------------
    // KODIPROP stream headers
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseStreamAsync_KodiPropStreamHeaders_Extracted()
    {
        // The parser looks for the literal prefix (no leading #):
        // "KODIPROP:inputstream.adaptive.stream_headers="
        const string m3u = "#EXTM3U\r\n" +
            "#EXTINF:-1 tvg-id=\"kodi\" tvg-name=\"Kodi\",Kodi Channel\r\n" +
            "KODIPROP:inputstream.adaptive.stream_headers=X-Token=abc123\r\n" +
            "https://stream.example.com/kodi.ts\r\n";

        using var stream = MakeStream(m3u);
        var parser = new M3UParser();

        var entries = new List<M3UEntry>();
        await foreach (var e in parser.ParseStreamAsync(stream))
            entries.Add(e);

        entries.Should().HaveCount(1);
        entries[0].KodiStreamHeaders.Should().Be("X-Token=abc123");
    }
}
