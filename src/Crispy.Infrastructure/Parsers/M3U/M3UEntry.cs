using Crispy.Domain.Enums;

namespace Crispy.Infrastructure.Parsers.M3U;

/// <summary>
/// A single parsed entry from an M3U playlist.
/// </summary>
public sealed class M3UEntry
{
    /// <summary>The stream URL.</summary>
    public required string Url { get; init; }

    /// <summary>Display title (text after the last comma on the #EXTINF line).</summary>
    public required string Title { get; init; }

    /// <summary>tvg-id attribute.</summary>
    public string? TvgId { get; init; }

    /// <summary>tvg-name attribute.</summary>
    public string? TvgName { get; init; }

    /// <summary>tvg-logo attribute (URL).</summary>
    public string? TvgLogo { get; init; }

    /// <summary>tvg-chno attribute (channel number).</summary>
    public int? TvgChno { get; init; }

    /// <summary>group-title attribute.</summary>
    public string? GroupTitle { get; init; }

    /// <summary>Whether this entry is a radio (audio-only) stream.</summary>
    public bool IsRadio { get; init; }

    /// <summary>Catchup/timeshift mode.</summary>
    public CatchupType CatchupType { get; init; } = CatchupType.None;

    /// <summary>Catchup URL template.</summary>
    public string? CatchupSource { get; init; }

    /// <summary>Number of catchup days available.</summary>
    public int CatchupDays { get; init; }

    /// <summary>HTTP User-Agent override from #EXTVLCOPT.</summary>
    public string? HttpUserAgent { get; init; }

    /// <summary>HTTP Referer override from #EXTVLCOPT.</summary>
    public string? HttpReferrer { get; init; }

    /// <summary>Raw stream headers from KODIPROP (key=value pairs).</summary>
    public string? KodiStreamHeaders { get; init; }

    /// <summary>True when this entry was parsed via the lenient (fallback) path.</summary>
    public bool IsLenientParsed { get; init; }
}
