using System.Globalization;
using System.IO.Compression;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Xml;

using Crispy.Domain.Entities;

namespace Crispy.Infrastructure.Parsers.Xmltv;

/// <summary>
/// SAX-style XMLTV parser using XmlReader. Supports GZip-compressed feeds.
/// All timestamps are normalized to UTC before storage.
/// </summary>
public sealed class XmltvParser
{
    private static readonly string[] XmltvDateFormats =
    [
        "yyyyMMddHHmmss zzz",
        "yyyyMMddHHmmss",
    ];

    /// <summary>
    /// Parses an XMLTV stream and yields EpgProgramme entities.
    /// </summary>
    public async IAsyncEnumerable<EpgProgramme> ParseAsync(
        Stream stream,
        bool isGzipped = false,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        Stream xmlStream = stream;
        GZipStream? gzip = null;

        if (isGzipped)
        {
            gzip = new GZipStream(stream, CompressionMode.Decompress, leaveOpen: true);
            xmlStream = gzip;
        }

        var settings = new XmlReaderSettings
        {
            Async = true,
            DtdProcessing = DtdProcessing.Ignore,
            XmlResolver = null,
            IgnoreWhitespace = true,
            IgnoreComments = true,
        };

        try
        {
            using var reader = XmlReader.Create(xmlStream, settings);

            while (await reader.ReadAsync().ConfigureAwait(false))
            {
                ct.ThrowIfCancellationRequested();

                if (reader.NodeType != XmlNodeType.Element || reader.Name != "programme")
                    continue;

                var programme = await ReadProgrammeAsync(reader, ct).ConfigureAwait(false);
                if (programme is not null)
                    yield return programme;
            }
        }
        finally
        {
            if (gzip is not null)
                await gzip.DisposeAsync().ConfigureAwait(false);
        }
    }

    private static async Task<EpgProgramme?> ReadProgrammeAsync(XmlReader reader, CancellationToken ct)
    {
        var startRaw = reader.GetAttribute("start");
        var stopRaw = reader.GetAttribute("stop");
        var channelId = reader.GetAttribute("channel");

        if (string.IsNullOrEmpty(startRaw) || string.IsNullOrEmpty(channelId))
            return null;

        var startUtc = ParseXmltvDate(startRaw);
        var stopUtc = stopRaw is not null ? ParseXmltvDate(stopRaw) : startUtc.AddHours(1);

        string? primaryTitle = null;
        string? subTitle = null;
        string? description = null;
        string? episodeNumXmltvNs = null;
        string? episodeNumOnScreen = null;
        string? rating = null;
        string? starRating = null;
        string? iconUrl = null;
        bool previouslyShown = false;
        var directors = new List<string>();
        var actors = new List<string>();
        var multiLangTitles = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        // Read all child elements of <programme>
        while (await reader.ReadAsync().ConfigureAwait(false))
        {
            ct.ThrowIfCancellationRequested();

            if (reader.NodeType == XmlNodeType.EndElement && reader.Name == "programme")
                break;

            if (reader.NodeType != XmlNodeType.Element)
                continue;

            var elementName = reader.Name;
            var lang = reader.GetAttribute("lang") ?? "und";
            var system = reader.GetAttribute("system");
            var src = reader.GetAttribute("src");
            bool isEmpty = reader.IsEmptyElement;

            switch (elementName)
            {
                case "title":
                    {
                        var text = isEmpty ? string.Empty : await ReadTextContentAsync(reader, "title", ct).ConfigureAwait(false);
                        if (primaryTitle is null)
                            primaryTitle = text;
                        if (!string.IsNullOrEmpty(text))
                            multiLangTitles[lang] = text;
                        break;
                    }

                case "sub-title":
                    subTitle = isEmpty ? null : await ReadTextContentAsync(reader, "sub-title", ct).ConfigureAwait(false);
                    break;

                case "desc":
                    description = isEmpty ? null : await ReadTextContentAsync(reader, "desc", ct).ConfigureAwait(false);
                    break;

                case "credits":
                    if (!isEmpty)
                        await ReadCreditsAsync(reader, directors, actors, ct).ConfigureAwait(false);
                    break;

                case "episode-num":
                    {
                        var epNum = isEmpty ? null : await ReadTextContentAsync(reader, "episode-num", ct).ConfigureAwait(false);
                        if (system == "xmltv_ns") episodeNumXmltvNs = epNum;
                        else if (system == "onscreen") episodeNumOnScreen = epNum;
                        break;
                    }

                case "rating":
                    if (!isEmpty)
                        rating = await ReadChildValueAsync(reader, "rating", "value", ct).ConfigureAwait(false);
                    break;

                case "star-rating":
                    if (!isEmpty)
                        starRating = await ReadChildValueAsync(reader, "star-rating", "value", ct).ConfigureAwait(false);
                    break;

                case "icon":
                    iconUrl = src;
                    // Empty element — no need to read content
                    break;

                case "previously-shown":
                    previouslyShown = true;
                    break;

                default:
                    if (!isEmpty)
                        await SkipElementAsync(reader, elementName, ct).ConfigureAwait(false);
                    break;
            }
        }

        if (primaryTitle is null)
            return null;

        string? creditsJson = null;
        if (directors.Count > 0 || actors.Count > 0)
        {
            creditsJson = JsonSerializer.Serialize(new
            {
                directors,
                actors,
            });
        }

        // Only store multi-lang if there is more than one language variant
        string? multiLangJson = multiLangTitles.Count > 1
            ? JsonSerializer.Serialize(multiLangTitles)
            : null;

        return new EpgProgramme
        {
            ChannelId = channelId!,
            StartUtc = DateTime.SpecifyKind(startUtc, DateTimeKind.Utc),
            StopUtc = DateTime.SpecifyKind(stopUtc, DateTimeKind.Utc),
            Title = primaryTitle,
            SubTitle = subTitle,
            Description = description,
            Credits = creditsJson,
            EpisodeNumXmltvNs = episodeNumXmltvNs,
            EpisodeNumOnScreen = episodeNumOnScreen,
            Rating = rating,
            StarRating = starRating,
            IconUrl = iconUrl,
            PreviouslyShown = previouslyShown,
            MultiLangTitles = multiLangJson,
        };
    }

    /// <summary>Reads the text content of the current element, advancing past its end tag.</summary>
    private static async Task<string> ReadTextContentAsync(XmlReader reader, string elementName, CancellationToken ct)
    {
        var sb = new System.Text.StringBuilder();

        while (await reader.ReadAsync().ConfigureAwait(false))
        {
            ct.ThrowIfCancellationRequested();

            if (reader.NodeType == XmlNodeType.EndElement && reader.Name == elementName)
                break;

            if (reader.NodeType is XmlNodeType.Text or XmlNodeType.CDATA)
                sb.Append(reader.Value);
        }

        return sb.ToString();
    }

    /// <summary>Reads a child element's text value from within a container element.</summary>
    private static async Task<string?> ReadChildValueAsync(
        XmlReader reader,
        string containerName,
        string childName,
        CancellationToken ct)
    {
        string? value = null;

        while (await reader.ReadAsync().ConfigureAwait(false))
        {
            ct.ThrowIfCancellationRequested();

            if (reader.NodeType == XmlNodeType.EndElement && reader.Name == containerName)
                break;

            if (reader.NodeType == XmlNodeType.Element && reader.Name == childName && !reader.IsEmptyElement)
                value = await ReadTextContentAsync(reader, childName, ct).ConfigureAwait(false);
        }

        return value;
    }

    /// <summary>Reads credits (director/actor) from within a &lt;credits&gt; element.</summary>
    private static async Task ReadCreditsAsync(
        XmlReader reader,
        List<string> directors,
        List<string> actors,
        CancellationToken ct)
    {
        while (await reader.ReadAsync().ConfigureAwait(false))
        {
            ct.ThrowIfCancellationRequested();

            if (reader.NodeType == XmlNodeType.EndElement && reader.Name == "credits")
                break;

            if (reader.NodeType != XmlNodeType.Element || reader.IsEmptyElement)
                continue;

            switch (reader.Name)
            {
                case "director":
                    directors.Add(await ReadTextContentAsync(reader, "director", ct).ConfigureAwait(false));
                    break;
                case "actor":
                    actors.Add(await ReadTextContentAsync(reader, "actor", ct).ConfigureAwait(false));
                    break;
                default:
                    await SkipElementAsync(reader, reader.Name, ct).ConfigureAwait(false);
                    break;
            }
        }
    }

    /// <summary>Skips past the end tag of the current element.</summary>
    private static async Task SkipElementAsync(XmlReader reader, string elementName, CancellationToken ct)
    {
        int depth = 1;
        while (depth > 0 && await reader.ReadAsync().ConfigureAwait(false))
        {
            ct.ThrowIfCancellationRequested();
            if (reader.NodeType == XmlNodeType.Element && !reader.IsEmptyElement)
                depth++;
            else if (reader.NodeType == XmlNodeType.EndElement)
                depth--;
        }
    }

    private static DateTime ParseXmltvDate(string raw)
    {
        if (DateTimeOffset.TryParseExact(
                raw.Trim(),
                XmltvDateFormats,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var dto))
        {
            return dto.UtcDateTime;
        }

        if (DateTime.TryParseExact(
                raw.Trim().Split(' ')[0],
                "yyyyMMddHHmmss",
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal,
                out var dt))
        {
            return dt.ToUniversalTime();
        }

        return DateTime.UtcNow;
    }
}
