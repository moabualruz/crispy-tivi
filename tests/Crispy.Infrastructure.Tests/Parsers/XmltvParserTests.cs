using System.IO.Compression;
using System.Text;
using System.Text.Json;

using Crispy.Infrastructure.Parsers.Xmltv;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

[Trait("Category", "Unit")]
public class XmltvParserTests
{
    private static string FixturePath(string name) =>
        Path.Combine(AppContext.BaseDirectory, "Fixtures", name);

    private static Stream XmlStream(string xml)
        => new MemoryStream(Encoding.UTF8.GetBytes(xml));

    private static async Task<List<Crispy.Domain.Entities.EpgProgramme>> ParseInlineAsync(
        string xml, bool isGzipped = false, CancellationToken ct = default)
    {
        var parser = new XmltvParser();
        var list = new List<Crispy.Domain.Entities.EpgProgramme>();
        await foreach (var p in parser.ParseAsync(XmlStream(xml), isGzipped, ct))
            list.Add(p);
        return list;
    }

    [Fact]
    public async Task ParseAsync_SampleXml_ReturnsThreeProgrammes()
    {
        await using var stream = File.OpenRead(FixturePath("sample.xml"));
        var parser = new XmltvParser();

        var programmes = new List<Crispy.Domain.Entities.EpgProgramme>();
        await foreach (var p in parser.ParseAsync(stream, isGzipped: false))
            programmes.Add(p);

        programmes.Should().HaveCount(3);
    }

    [Fact]
    public async Task ParseAsync_StartUtc_IsUtcKind()
    {
        await using var stream = File.OpenRead(FixturePath("sample.xml"));
        var parser = new XmltvParser();

        var programmes = new List<Crispy.Domain.Entities.EpgProgramme>();
        await foreach (var p in parser.ParseAsync(stream, isGzipped: false))
            programmes.Add(p);

        foreach (var p in programmes)
        {
            p.StartUtc.Kind.Should().Be(DateTimeKind.Utc, "all times must be stored as UTC");
            p.StopUtc.Kind.Should().Be(DateTimeKind.Utc);
        }
    }

    [Fact]
    public async Task ParseAsync_PlusOneOffset_StoredAsCorrectUtc()
    {
        // Programme start="20240315143000 +0100" => UTC 13:30:00
        await using var stream = File.OpenRead(FixturePath("sample.xml"));
        var parser = new XmltvParser();

        var programmes = new List<Crispy.Domain.Entities.EpgProgramme>();
        await foreach (var p in parser.ParseAsync(stream, isGzipped: false))
            programmes.Add(p);

        var afternoon = programmes.FirstOrDefault(p => p.Title == "Afternoon Show");
        afternoon.Should().NotBeNull();
        afternoon!.StartUtc.Should().Be(new DateTime(2024, 3, 15, 13, 30, 0, DateTimeKind.Utc));
        afternoon.StopUtc.Should().Be(new DateTime(2024, 3, 15, 14, 0, 0, DateTimeKind.Utc));
    }

    [Fact]
    public async Task ParseAsync_Credits_SerializedToJson()
    {
        await using var stream = File.OpenRead(FixturePath("sample.xml"));
        var parser = new XmltvParser();

        var programmes = new List<Crispy.Domain.Entities.EpgProgramme>();
        await foreach (var p in parser.ParseAsync(stream, isGzipped: false))
            programmes.Add(p);

        var newsAtOne = programmes.FirstOrDefault(p => p.Title == "News at One");
        newsAtOne.Should().NotBeNull();
        newsAtOne!.Credits.Should().NotBeNullOrEmpty();

        var credits = JsonSerializer.Deserialize<JsonElement>(newsAtOne.Credits!);
        credits.GetProperty("directors").EnumerateArray().First().GetString().Should().Be("Jane Smith");
        credits.GetProperty("actors").EnumerateArray().First().GetString().Should().Be("John Doe");
    }

    [Fact]
    public async Task ParseAsync_GzippedStream_SameResultAsUncompressed()
    {
        // Create gzip of sample.xml in memory
        var xmlBytes = await File.ReadAllBytesAsync(FixturePath("sample.xml"));
        using var gzipMs = new MemoryStream();
        await using (var gzip = new GZipStream(gzipMs, CompressionLevel.Fastest, leaveOpen: true))
            await gzip.WriteAsync(xmlBytes);
        gzipMs.Position = 0;

        var parser = new XmltvParser();
        var gzipProgrammes = new List<Crispy.Domain.Entities.EpgProgramme>();
        await foreach (var p in parser.ParseAsync(gzipMs, isGzipped: true))
            gzipProgrammes.Add(p);

        gzipProgrammes.Should().HaveCount(3);
        gzipProgrammes.Select(p => p.Title).Should().Contain("News at One");
    }

    [Fact]
    public async Task ParseAsync_MultiLangTitles_StoredAsJson()
    {
        await using var stream = File.OpenRead(FixturePath("sample.xml"));
        var parser = new XmltvParser();

        var programmes = new List<Crispy.Domain.Entities.EpgProgramme>();
        await foreach (var p in parser.ParseAsync(stream, isGzipped: false))
            programmes.Add(p);

        var newsAtOne = programmes.FirstOrDefault(p => p.Title == "News at One");
        newsAtOne!.MultiLangTitles.Should().NotBeNullOrEmpty();
        var langs = JsonSerializer.Deserialize<JsonElement>(newsAtOne.MultiLangTitles!);
        langs.GetProperty("fr").GetString().Should().Be("Nouvelles");
    }

    // ------------------------------------------------------------------
    // Missing channel attribute → entry skipped
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_SkipsEntry_WhenChannelAttributeMissing()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000">
                <title>No Channel</title>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().BeEmpty();
    }

    // ------------------------------------------------------------------
    // Missing start attribute → entry skipped
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_SkipsEntry_WhenStartAttributeMissing()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme stop="20240101130000 +0000" channel="ch1">
                <title>No Start</title>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().BeEmpty();
    }

    // ------------------------------------------------------------------
    // Empty <tv> element → nothing yielded
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_YieldsNothing_WhenEmptyTvElement()
    {
        const string xml = """<?xml version="1.0"?><tv></tv>""";

        var result = await ParseInlineAsync(xml);

        result.Should().BeEmpty();
    }

    // ------------------------------------------------------------------
    // previously-shown element sets PreviouslyShown = true
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_SetsPreviouslyShownTrue_WhenElementPresent()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Repeat</title>
                <previously-shown/>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].PreviouslyShown.Should().BeTrue();
    }

    // ------------------------------------------------------------------
    // Optional fields: subtitle, description, icon
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_PopulatesOptionalFields_WhenSubtitleDescIconPresent()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Full Show</title>
                <sub-title>Episode One</sub-title>
                <desc>A gripping drama.</desc>
                <icon src="https://example.com/icon.png"/>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].SubTitle.Should().Be("Episode One");
        result[0].Description.Should().Be("A gripping drama.");
        result[0].IconUrl.Should().Be("https://example.com/icon.png");
    }

    // ------------------------------------------------------------------
    // Rating value parsed
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_PopulatesRating_WhenRatingElementPresent()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Rated Show</title>
                <rating system="MPAA"><value>PG-13</value></rating>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].Rating.Should().Be("PG-13");
    }

    // ------------------------------------------------------------------
    // Star rating parsed
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_PopulatesStarRating_WhenStarRatingElementPresent()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Star Show</title>
                <star-rating><value>4/5</value></star-rating>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].StarRating.Should().Be("4/5");
    }

    // ------------------------------------------------------------------
    // Episode-num elements parsed
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_PopulatesEpisodeNumbers_WhenEpisodeNumElementsPresent()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Series</title>
                <episode-num system="xmltv_ns">0.5.0/1</episode-num>
                <episode-num system="onscreen">S01E06</episode-num>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].EpisodeNumXmltvNs.Should().Be("0.5.0/1");
        result[0].EpisodeNumOnScreen.Should().Be("S01E06");
    }

    // ------------------------------------------------------------------
    // Stop defaults to start + 1h when stop attribute absent
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_DefaultsStopToStartPlusOneHour_WhenStopAttributeMissing()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" channel="ch1">
                <title>No Stop</title>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        (result[0].StopUtc - result[0].StartUtc).Should().Be(TimeSpan.FromHours(1));
    }

    // ------------------------------------------------------------------
    // Cancellation stops enumeration
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_ThrowsOperationCanceledException_WhenCancelledBeforeStart()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Prog</title>
              </programme>
            </tv>
            """;

        using var cts = new CancellationTokenSource();
        cts.Cancel();

        var parser = new XmltvParser();

        var act = async () =>
        {
            await foreach (var _ in parser.ParseAsync(XmlStream(xml), false, cts.Token))
            {
                // consume
            }
        };

        await act.Should().ThrowAsync<OperationCanceledException>();
    }

    // ------------------------------------------------------------------
    // Multi-language titles via inline XML (no fixture dependency)
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_PopulatesMultiLangTitles_WhenMultipleTitleLanguagesInline()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title lang="en">English Title</title>
                <title lang="de">Deutsches Titel</title>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].Title.Should().Be("English Title");
        result[0].MultiLangTitles.Should().NotBeNullOrEmpty();
        result[0].MultiLangTitles.Should().Contain("Deutsches Titel");
    }

    // ------------------------------------------------------------------
    // Single-language title: MultiLangTitles stays null (not persisted)
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_MultiLangTitlesIsNull_WhenOnlyOneTitleLanguage()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title lang="en">Only English</title>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].MultiLangTitles.Should().BeNull();
    }

    // ------------------------------------------------------------------
    // Credits with actors serialized (covers ReadCreditsAsync actor branch)
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_CreditsWithActors_SerializedToJson()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Drama</title>
                <credits>
                  <director>Jane Smith</director>
                  <actor>John Doe</actor>
                  <actor>Alice Brown</actor>
                </credits>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].Credits.Should().NotBeNullOrEmpty();
        result[0].Credits.Should().Contain("Jane Smith");
        result[0].Credits.Should().Contain("John Doe");
    }

    // ------------------------------------------------------------------
    // Unknown child element is skipped gracefully (SkipElementAsync)
    // ------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_UnknownChildElement_IsSkippedAndProgrammeStillYielded()
    {
        const string xml = """
            <?xml version="1.0"?>
            <tv>
              <programme start="20240101120000 +0000" stop="20240101130000 +0000" channel="ch1">
                <title>Show</title>
                <unknown-tag>some content</unknown-tag>
                <another-unknown><nested/></another-unknown>
              </programme>
            </tv>
            """;

        var result = await ParseInlineAsync(xml);

        result.Should().HaveCount(1);
        result[0].Title.Should().Be("Show");
    }
}
