using Crispy.Application.Security;
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
    private readonly ICredentialEncryption _credentialEncryption;
    private readonly ILogger<XtreamParser> _logger;

    /// <summary>Creates a new XtreamParser.</summary>
    public XtreamParser(XtreamClient client, M3UParser m3uParser, ICredentialEncryption credentialEncryption, ILogger<XtreamParser> logger)
    {
        _client = client;
        _m3uParser = m3uParser;
        _credentialEncryption = credentialEncryption;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default)
    {
        var username = source.EncryptedUsername is not null
            ? _credentialEncryption.Decrypt(source.EncryptedUsername)
            : source.Username ?? string.Empty;
        var password = source.EncryptedPassword is not null
            ? _credentialEncryption.Decrypt(source.EncryptedPassword)
            : source.Password ?? string.Empty;

        try
        {
            _client.BaseUrl = source.Url;
            var auth = await _client.AuthenticateAsync(username, password, ct).ConfigureAwait(false);
            if (auth is null)
                return await FallbackToM3UAsync(source, username, password, ct).ConfigureAwait(false);

            var channels = new List<Channel>();
            var movies = new List<Movie>();
            var series = new List<Series>();

            var baseUrl = source.Url.TrimEnd('/');

            using var liveDoc = await _client.GetLiveStreamsAsync(username, password, ct).ConfigureAwait(false);
            if (liveDoc is not null)
            {
                foreach (var el in liveDoc.RootElement.EnumerateArray())
                {
                    var streamId = el.TryGetProperty("stream_id", out var sid) ? sid.ToString() : null;
                    var channel = new Channel
                    {
                        Title = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown",
                        ExternalId = streamId,
                        TvgId = el.TryGetProperty("epg_channel_id", out var eid) ? eid.GetString() : null,
                        TvgLogo = el.TryGetProperty("stream_icon", out var ico) ? ico.GetString() : null,
                        GroupName = el.TryGetProperty("category_name", out var g) ? g.GetString() : null,
                        SourceId = source.Id,
                    };

                    if (streamId is not null)
                    {
                        channel.StreamEndpoints.Add(new StreamEndpoint
                        {
                            ChannelId = 0, // EF resolves after channel insert
                            SourceId = source.Id,
                            Url = $"{baseUrl}/live/{Uri.EscapeDataString(username)}/{Uri.EscapeDataString(password)}/{streamId}.ts",
                            Format = StreamFormat.MpegTs,
                            Priority = 0,
                        });
                    }

                    channels.Add(channel);
                }
            }

            using var vodDoc = await _client.GetVodStreamsAsync(username, password, ct).ConfigureAwait(false);
            if (vodDoc is not null)
            {
                foreach (var el in vodDoc.RootElement.EnumerateArray())
                {
                    var vodStreamId = el.TryGetProperty("stream_id", out var vsid) ? vsid.ToString() : null;
                    var containerExt = el.TryGetProperty("container_extension", out var ext) ? ext.GetString() : "ts";

                    movies.Add(new Movie
                    {
                        Title = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown",
                        Thumbnail = el.TryGetProperty("stream_icon", out var ico) ? ico.GetString() : null,
                        StreamUrl = vodStreamId is not null
                            ? $"{baseUrl}/movie/{Uri.EscapeDataString(username)}/{Uri.EscapeDataString(password)}/{vodStreamId}.{containerExt ?? "ts"}"
                            : null,
                        SourceId = source.Id,
                    });
                }
            }

            var episodes = new List<Episode>();
            var episodeSeriesNames = new Dictionary<int, string>();

            using var seriesDoc = await _client.GetSeriesAsync(username, password, ct).ConfigureAwait(false);
            if (seriesDoc is not null)
            {
                foreach (var el in seriesDoc.RootElement.EnumerateArray())
                {
                    var seriesName = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown";
                    var xtreamSeriesId = el.TryGetProperty("series_id", out var sid) ? sid.ToString() : null;

                    series.Add(new Series
                    {
                        Title = seriesName,
                        Thumbnail = el.TryGetProperty("cover", out var cover) ? cover.GetString() : null,
                        SourceId = source.Id,
                    });

                    // Fetch episodes for this series
                    if (xtreamSeriesId is not null)
                    {
                        try
                        {
                            using var infoDoc = await _client.GetSeriesInfoAsync(username, password, xtreamSeriesId, ct).ConfigureAwait(false);
                            if (infoDoc is not null && infoDoc.RootElement.TryGetProperty("episodes", out var episodesObj))
                            {
                                foreach (var seasonProp in episodesObj.EnumerateObject())
                                {
                                    _ = int.TryParse(seasonProp.Name, out var seasonNum);
                                    if (seasonNum == 0) seasonNum = 1;

                                    foreach (var ep in seasonProp.Value.EnumerateArray())
                                    {
                                        var epId = ep.TryGetProperty("id", out var eid) ? eid.ToString() : null;
                                        var epNum = ep.TryGetProperty("episode_num", out var en) && int.TryParse(en.ToString(), out var epNumVal) ? epNumVal : 1;
                                        var epTitle = ep.TryGetProperty("title", out var et) ? et.GetString() ?? $"Episode {epNum}" : "Unknown";
                                        var containerExt = ep.TryGetProperty("container_extension", out var ext) ? ext.GetString() : "ts";

                                        string? thumbnail = null;
                                        if (ep.TryGetProperty("info", out var info))
                                        {
                                            thumbnail = info.TryGetProperty("movie_image", out var img) ? img.GetString() : null;
                                        }

                                        var streamUrl = epId is not null
                                            ? $"{baseUrl}/series/{Uri.EscapeDataString(username)}/{Uri.EscapeDataString(password)}/{epId}.{containerExt ?? "ts"}"
                                            : null;

                                        episodeSeriesNames[episodes.Count] = seriesName;
                                        episodes.Add(new Episode
                                        {
                                            Title = epTitle,
                                            SourceId = source.Id,
                                            SeriesId = 1, // Placeholder — resolved by SyncPipeline
                                            SeasonNumber = seasonNum,
                                            EpisodeNumber = epNum,
                                            StreamUrl = streamUrl,
                                            Thumbnail = thumbnail,
                                        });
                                    }
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogDebug(ex, "Failed to fetch episodes for Xtream series {SeriesId}", xtreamSeriesId);
                        }
                    }
                }
            }

            return new ParseResult
            {
                Channels = channels,
                StreamEndpoints = channels.SelectMany(c => c.StreamEndpoints).ToList(),
                Movies = movies,
                Series = series,
                Episodes = episodes,
                EpisodeSeriesNames = episodeSeriesNames,
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

        try
        {
            await using var stream = await _client.GetM3UStreamAsync(m3uUrl, ct).ConfigureAwait(false);
            var channels = new List<Channel>();
            int skipped = 0;

            await foreach (var entry in _m3uParser.ParseStreamAsync(stream, ct).ConfigureAwait(false))
            {
                var channel = new Channel
                {
                    Title = entry.Title,
                    ExternalId = entry.Url,
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
                };

                channel.StreamEndpoints.Add(new StreamEndpoint
                {
                    ChannelId = 0, // EF resolves after channel insert
                    SourceId = source.Id,
                    Url = entry.Url ?? string.Empty,
                    Format = DetectFormat(entry.Url),
                    Priority = 0,
                });

                channels.Add(channel);
            }

            return new ParseResult
            {
                Channels = channels,
                StreamEndpoints = channels.SelectMany(c => c.StreamEndpoints).ToList(),
                SkippedCount = skipped,
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "M3U fallback also failed for source {SourceId}", source.Id);
            return new ParseResult { Error = ex.Message };
        }
    }

    private static StreamFormat DetectFormat(string? url)
    {
        if (url is null) return StreamFormat.Unknown;
        if (url.Contains(".m3u8", StringComparison.OrdinalIgnoreCase)) return StreamFormat.HLS;
        if (url.Contains(".ts", StringComparison.OrdinalIgnoreCase)) return StreamFormat.MpegTs;
        if (url.StartsWith("rtmp://", StringComparison.OrdinalIgnoreCase)) return StreamFormat.Rtmp;
        if (url.StartsWith("rtsp://", StringComparison.OrdinalIgnoreCase)) return StreamFormat.Rtsp;
        if (url.StartsWith("udp://", StringComparison.OrdinalIgnoreCase)) return StreamFormat.Udp;
        return StreamFormat.Unknown;
    }
}
