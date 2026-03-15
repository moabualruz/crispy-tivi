using System.Runtime.CompilerServices;
using System.Text;
using System.Text.RegularExpressions;

using Crispy.Domain.Enums;

namespace Crispy.Infrastructure.Parsers.M3U;

/// <summary>
/// Streaming line-by-line M3U parser. Never buffers the entire file into memory.
/// Two-pass per entry: strict regex first, lenient fallback for malformed entries.
/// </summary>
public sealed partial class M3UParser
{
    // Strict: attribute="value" or attribute=value (no spaces in unquoted value)
    [GeneratedRegex("""(\w[\w-]*)=(?:"([^"]*?)"|(\S+))""", RegexOptions.Compiled)]
    private static partial Regex StrictAttrRegex();

    // Lenient: attribute=value where value may run to next attribute name
    [GeneratedRegex("""(\w[\w-]*)=([^\s,][^=]*?)(?=\s+\w[\w-]*=|\s*$)""", RegexOptions.Compiled)]
    private static partial Regex LenientAttrRegex();

    private static readonly Encoding Latin1 = Encoding.Latin1;

    /// <summary>
    /// Asynchronously streams M3UEntry records from the given stream.
    /// Never loads the whole file into memory.
    /// </summary>
    public async IAsyncEnumerable<M3UEntry> ParseStreamAsync(
        Stream stream,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        using var reader = new StreamReader(stream, detectEncodingFromByteOrderMarks: true, leaveOpen: true);

        string? extinf = null;
        string? userAgent = null;
        string? referrer = null;
        string? kodiHeaders = null;

        string? rawLine;
        while ((rawLine = await reader.ReadLineAsync(ct).ConfigureAwait(false)) is not null)
        {
            var line = rawLine.Trim();

            if (line.Length == 0)
                continue;

            if (line.StartsWith("#EXTM3U", StringComparison.OrdinalIgnoreCase))
                continue;

            if (line.StartsWith("#EXTINF", StringComparison.OrdinalIgnoreCase))
            {
                extinf = line;
                userAgent = null;
                referrer = null;
                kodiHeaders = null;
                continue;
            }

            if (line.StartsWith("#EXTVLCOPT:http-user-agent=", StringComparison.OrdinalIgnoreCase))
            {
                userAgent = line.Substring("#EXTVLCOPT:http-user-agent=".Length);
                continue;
            }

            if (line.StartsWith("#EXTVLCOPT:http-referrer=", StringComparison.OrdinalIgnoreCase))
            {
                referrer = line.Substring("#EXTVLCOPT:http-referrer=".Length);
                continue;
            }

            if (line.StartsWith("KODIPROP:inputstream.adaptive.stream_headers=", StringComparison.OrdinalIgnoreCase))
            {
                kodiHeaders = line.Substring("KODIPROP:inputstream.adaptive.stream_headers=".Length);
                continue;
            }

            // Skip other comment/directive lines (but not URLs)
            if (line.StartsWith('#'))
                continue;

            // This is a URL line — if we have a pending EXTINF, emit an entry
            if (extinf is not null)
            {
                var entry = TryParseStrict(extinf, line, userAgent, referrer, kodiHeaders)
                         ?? ParseLenient(extinf, line, userAgent, referrer, kodiHeaders);

                extinf = null;
                userAgent = null;
                referrer = null;
                kodiHeaders = null;

                if (entry is not null)
                    yield return entry;
            }
        }
    }

    private static M3UEntry? TryParseStrict(
        string extinf,
        string url,
        string? userAgent,
        string? referrer,
        string? kodiHeaders)
    {
        // Title is everything after the last comma
        var commaIdx = extinf.LastIndexOf(',');
        if (commaIdx < 0)
            return null;

        var title = extinf[(commaIdx + 1)..].Trim();
        if (string.IsNullOrEmpty(title))
            return null;

        var attrPart = extinf[..commaIdx];

        // Count '=' occurrences to estimate expected number of attributes.
        // If there are unmatched/odd quotes in the attribute section, fall through to lenient parse.
        var quoteCount = attrPart.Count(c => c == '"');
        var hasUnclosedQuote = quoteCount % 2 != 0;
        var matches = StrictAttrRegex().Matches(attrPart);
        var hasEquals = attrPart.Contains('=');
        if (hasEquals && (matches.Count == 0 || hasUnclosedQuote))
            return null;

        var attrs = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (Match m in matches)
        {
            var key = m.Groups[1].Value;
            var val = m.Groups[2].Success ? m.Groups[2].Value
                    : m.Groups[3].Success ? m.Groups[3].Value
                    : string.Empty;
            attrs[key] = val.Trim();
        }

        return BuildEntry(title, url, attrs, userAgent, referrer, kodiHeaders, isLenient: false);
    }

    private static M3UEntry ParseLenient(
        string extinf,
        string url,
        string? userAgent,
        string? referrer,
        string? kodiHeaders)
    {
        var commaIdx = extinf.LastIndexOf(',');
        var title = commaIdx >= 0 ? extinf[(commaIdx + 1)..].Trim() : string.Empty;
        if (string.IsNullOrEmpty(title))
            title = url;

        var attrPart = commaIdx >= 0 ? extinf[..commaIdx] : extinf;
        var attrs = ParseAttributes(LenientAttrRegex(), attrPart);

        return BuildEntry(title, url, attrs, userAgent, referrer, kodiHeaders, isLenient: true)
            ?? new M3UEntry { Title = title, Url = url, IsLenientParsed = true };
    }

    private static Dictionary<string, string> ParseAttributes(Regex regex, string attrPart)
    {
        var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (Match m in regex.Matches(attrPart))
        {
            var key = m.Groups[1].Value;
            // Group 2 = quoted value, Group 3 = unquoted value (strict); Group 2 = value (lenient)
            var val = m.Groups[2].Success ? m.Groups[2].Value
                    : m.Groups[3].Success ? m.Groups[3].Value
                    : string.Empty;
            dict[key] = val.Trim();
        }
        return dict;
    }

    private static M3UEntry? BuildEntry(
        string title,
        string url,
        Dictionary<string, string> attrs,
        string? userAgent,
        string? referrer,
        string? kodiHeaders,
        bool isLenient)
    {
        if (string.IsNullOrEmpty(title))
            return null;

        attrs.TryGetValue("tvg-chno", out var chnoStr);
        int? tvgChno = int.TryParse(chnoStr, out var chno) ? chno : null;

        attrs.TryGetValue("catchup-days", out var daysStr);
        int catchupDays = int.TryParse(daysStr, out var days) ? days : 0;

        attrs.TryGetValue("radio", out var radioStr);
        bool isRadio = radioStr is "1" or "true";

        attrs.TryGetValue("catchup", out var catchupStr);
        var catchupType = ParseCatchupType(catchupStr);

        attrs.TryGetValue("tvg-id", out var tvgId);
        attrs.TryGetValue("tvg-name", out var tvgName);
        attrs.TryGetValue("tvg-logo", out var tvgLogo);
        attrs.TryGetValue("group-title", out var groupTitle);
        attrs.TryGetValue("catchup-source", out var catchupSource);

        return new M3UEntry
        {
            Title = title,
            Url = url,
            TvgId = NullIfEmpty(tvgId),
            TvgName = NullIfEmpty(tvgName),
            TvgLogo = NullIfEmpty(tvgLogo),
            TvgChno = tvgChno,
            GroupTitle = NullIfEmpty(groupTitle),
            IsRadio = isRadio,
            CatchupType = catchupType,
            CatchupSource = NullIfEmpty(catchupSource),
            CatchupDays = catchupDays,
            HttpUserAgent = userAgent,
            HttpReferrer = referrer,
            KodiStreamHeaders = kodiHeaders,
            IsLenientParsed = isLenient,
        };
    }

    private static CatchupType ParseCatchupType(string? value) => value?.ToLowerInvariant() switch
    {
        "default" => CatchupType.Default,
        "append" => CatchupType.Append,
        "shift" => CatchupType.Shift,
        "flussonic" => CatchupType.Flussonic,
        "xc" => CatchupType.Xc,
        _ => CatchupType.None,
    };

    private static string? NullIfEmpty(string? s) =>
        string.IsNullOrWhiteSpace(s) ? null : s;
}
