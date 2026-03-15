using System.IO.Compression;
using System.Text.Json;

using Crispy.Infrastructure.Parsers.Xmltv;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

public class XmltvParserTests
{
    private static string FixturePath(string name) =>
        Path.Combine(AppContext.BaseDirectory, "Fixtures", name);

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
}
