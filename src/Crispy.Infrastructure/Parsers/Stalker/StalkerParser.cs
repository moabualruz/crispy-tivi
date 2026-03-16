using Crispy.Application.Sources;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Parsers.Stalker;

/// <summary>
/// ISourceParser implementation for Stalker Portal (Ministra/MAG) middleware.
/// </summary>
public sealed class StalkerParser : ISourceParser
{
    private readonly StalkerClient _client;
    private readonly ILogger<StalkerParser> _logger;

    /// <summary>Creates a new StalkerParser.</summary>
    public StalkerParser(StalkerClient client, ILogger<StalkerParser> logger)
    {
        _client = client;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default)
    {
        try
        {
            // Set the base address from the source URL before every sync so the
            // singleton StalkerClient targets the correct portal per-source.
            _client.SetBaseAddress(source.Url);
            await _client.HandshakeAsync(ct).ConfigureAwait(false);

            var channels = new List<Channel>();
            var movies = new List<Movie>();

            using var channelsDoc = await _client.GetChannelsAsync(ct).ConfigureAwait(false);
            if (channelsDoc is not null && channelsDoc.RootElement.TryGetProperty("js", out var js))
            {
                var data = js.ValueKind == System.Text.Json.JsonValueKind.Object && js.TryGetProperty("data", out var d) ? d : js;
                if (data.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    foreach (var el in data.EnumerateArray())
                    {
                        // Stalker portals expose the stream URL in the "cmd" field.
                        var cmd = el.TryGetProperty("cmd", out var c) ? c.GetString() : null;

                        var channel = new Channel
                        {
                            Title = el.TryGetProperty("name", out var n) ? n.GetString() ?? "Unknown" : "Unknown",
                            ExternalId = el.TryGetProperty("id", out var id) ? id.ToString() : null,
                            TvgId = el.TryGetProperty("xmltv_id", out var xid) ? xid.GetString() : null,
                            TvgLogo = el.TryGetProperty("logo", out var l) ? l.GetString() : null,
                            SourceId = source.Id,
                        };

                        if (cmd is not null)
                        {
                            channel.StreamEndpoints.Add(new StreamEndpoint
                            {
                                ChannelId = 0, // EF resolves after channel insert
                                SourceId = source.Id,
                                Url = cmd,
                                Format = StreamFormat.Unknown,
                                Priority = 0,
                            });
                        }

                        channels.Add(channel);
                    }
                }
            }

            using var vodCatDoc = await _client.GetVodCategoriesAsync(ct).ConfigureAwait(false);
            if (vodCatDoc is not null && vodCatDoc.RootElement.TryGetProperty("js", out var catJs))
            {
                var categories = catJs.TryGetProperty("data", out var d) ? d : catJs;
                if (categories.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    foreach (var cat in categories.EnumerateArray())
                    {
                        var catId = cat.TryGetProperty("id", out var cid) ? cid.GetString() ?? "" : "";
                        using var vodDoc = await _client.GetVodListAsync(catId, ct: ct).ConfigureAwait(false);
                        if (vodDoc is null)
                            continue;

                        if (vodDoc.RootElement.TryGetProperty("js", out var vodJs))
                        {
                            var items = vodJs.TryGetProperty("data", out var vd) ? vd : vodJs;
                            if (items.ValueKind == System.Text.Json.JsonValueKind.Array)
                            {
                                foreach (var item in items.EnumerateArray())
                                {
                                    movies.Add(new Movie
                                    {
                                        Title = item.TryGetProperty("name", out var mn) ? mn.GetString() ?? "Unknown" : "Unknown",
                                        SourceId = source.Id,
                                    });
                                }
                            }
                        }
                    }
                }
            }

            return new ParseResult
            {
                Channels = channels,
                StreamEndpoints = channels.SelectMany(c => c.StreamEndpoints).ToList(),
                Movies = movies,
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Stalker Portal parse failed for source {SourceId}", source.Id);
            return new ParseResult { Error = ex.Message };
        }
    }
}
