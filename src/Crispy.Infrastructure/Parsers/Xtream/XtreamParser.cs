using Crispy.Application.Sources;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.M3U;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Parsers.Xtream;

/// <summary>
/// ISourceParser implementation for Xtream Codes API.
/// Tries the JSON API first; falls back to M3U URL on failure.
/// </summary>
public sealed class XtreamParser : ISourceParser
{
    private readonly XtreamClient _client;
    private readonly M3UParser _m3uParser;
    private readonly ILogger<XtreamParser> _logger;

    /// <summary>Creates a new XtreamParser.</summary>
    public XtreamParser(XtreamClient client, M3UParser m3uParser, ILogger<XtreamParser> logger)
    {
        _client = client;
        _m3uParser = m3uParser;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default)
    {
        var username = source.Username ?? string.Empty;
        var password = source.Password ?? string.Empty;

        try
        {
            var auth = await _client.AuthenticateAsync(username, password, ct).ConfigureAwait(false);
            if (auth is null)
                return await FallbackToM3UAsync(source, username, password, ct).ConfigureAwait(false);

            var channels = new List<Channel>();
            var movies = new List<Movie>();
            var series = new List<Series>();

            using var liveDoc = await _client.GetLiveStreamsAsync(username, password, ct).ConfigureAwait(false);
            if (liveDoc is not null)
            {
                foreach (var el in liveDoc.RootElement.EnumerateArray())
                {
                    channels.Add(new Channel
                    {
                        Title = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown",
                        TvgId = el.TryGetProperty("epg_channel_id", out var eid) ? eid.GetString() : null,
                        TvgLogo = el.TryGetProperty("stream_icon", out var ico) ? ico.GetString() : null,
                        GroupName = el.TryGetProperty("category_name", out var g) ? g.GetString() : null,
                        SourceId = source.Id,
                    });
                }
            }

            using var vodDoc = await _client.GetVodStreamsAsync(username, password, ct).ConfigureAwait(false);
            if (vodDoc is not null)
            {
                foreach (var el in vodDoc.RootElement.EnumerateArray())
                {
                    movies.Add(new Movie
                    {
                        Title = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown",
                        Thumbnail = el.TryGetProperty("stream_icon", out var ico) ? ico.GetString() : null,
                        SourceId = source.Id,
                    });
                }
            }

            using var seriesDoc = await _client.GetSeriesAsync(username, password, ct).ConfigureAwait(false);
            if (seriesDoc is not null)
            {
                foreach (var el in seriesDoc.RootElement.EnumerateArray())
                {
                    series.Add(new Series
                    {
                        Title = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown",
                        SourceId = source.Id,
                    });
                }
            }

            return new ParseResult
            {
                Channels = channels,
                Movies = movies,
                Series = series,
            };
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning(ex, "Xtream JSON API failed for source {SourceId}; falling back to M3U URL", source.Id);
            return await FallbackToM3UAsync(source, username, password, ct).ConfigureAwait(false);
        }
    }

    private async Task<ParseResult> FallbackToM3UAsync(
        Source source,
        string username,
        string password,
        CancellationToken ct)
    {
        var m3uUrl = $"{source.Url.TrimEnd('/')}/get.php?username={Uri.EscapeDataString(username)}&password={Uri.EscapeDataString(password)}&type=m3u_plus&output=ts";

        using var httpClient = new HttpClient();
        try
        {
            await using var stream = await httpClient.GetStreamAsync(m3uUrl, ct).ConfigureAwait(false);
            var channels = new List<Channel>();
            int skipped = 0;

            await foreach (var entry in _m3uParser.ParseStreamAsync(stream, ct).ConfigureAwait(false))
            {
                channels.Add(new Channel
                {
                    Title = entry.Title,
                    TvgId = entry.TvgId,
                    TvgName = entry.TvgName,
                    TvgLogo = entry.TvgLogo,
                    TvgChno = entry.TvgChno,
                    GroupName = entry.GroupTitle,
                    IsRadio = entry.IsRadio,
                    CatchupType = entry.CatchupType,
                    CatchupSource = entry.CatchupSource,
                    CatchupDays = entry.CatchupDays,
                    SourceId = source.Id,
                });
            }

            return new ParseResult { Channels = channels, SkippedCount = skipped };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "M3U fallback also failed for source {SourceId}", source.Id);
            return new ParseResult { Error = ex.Message };
        }
    }
}
