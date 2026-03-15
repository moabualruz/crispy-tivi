using System.Net;

using Crispy.Application.Sources;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Security;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Jellyfin;

/// <summary>
/// Parses all content from a Jellyfin media server into domain entities.
/// Implements ISourceParser so it plugs into the standard SyncPipeline.
/// </summary>
public sealed class JellyfinSyncService : ISourceParser
{
    private readonly Func<Source, JellyfinClient> _clientFactory;
    private readonly ILogger<JellyfinSyncService> _logger;

    private const string ImageBaseUrl = "https://image.tmdb.org/t/p/w500";

    /// <summary>Creates a new JellyfinSyncService.</summary>
    public JellyfinSyncService(
        Func<Source, JellyfinClient> clientFactory,
        ILogger<JellyfinSyncService> logger)
    {
        _clientFactory = clientFactory;
        _logger = logger;
    }

    /// <inheritdoc/>
    public async Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default)
    {
        var client = _clientFactory(source);

        try
        {
            // Authenticate using stored credentials
            if (!string.IsNullOrEmpty(source.Username) && !string.IsNullOrEmpty(source.Password))
            {
                await client.AuthenticateAsync(source.Username, source.Password, ct).ConfigureAwait(false);
            }
            else if (client.AccessToken is null)
            {
                _logger.LogWarning("Jellyfin source {SourceId} has no credentials — skipping", source.Id);
                return new ParseResult { Error = "No credentials configured for Jellyfin source." };
            }

            var libraries = await client.GetLibrariesAsync(ct).ConfigureAwait(false);
            _logger.LogInformation("Jellyfin source {SourceId}: found {Count} libraries", source.Id, libraries.Count);

            var movies = new List<Movie>();
            var series = new List<Series>();
            var episodes = new List<Episode>();
            var channels = new List<Channel>();

            foreach (var lib in libraries)
            {
                var collectionType = lib.Type?.ToLowerInvariant() ?? string.Empty;

                switch (collectionType)
                {
                    case "movies":
                        var movieItems = await FetchAllItemsAsync(client, lib.Id, "Movie", ct).ConfigureAwait(false);
                        movies.AddRange(movieItems.Select(i => MapMovie(i, source.Id)));
                        break;

                    case "tvshows":
                        var seriesItems = await FetchAllItemsAsync(client, lib.Id, "Series", ct).ConfigureAwait(false);
                        series.AddRange(seriesItems.Select(i => MapSeries(i, source.Id)));

                        var episodeItems = await FetchAllItemsAsync(client, lib.Id, "Episode", ct).ConfigureAwait(false);
                        episodes.AddRange(episodeItems.Select(i => MapEpisode(i, source.Id, seriesItems)));
                        break;

                    case "livetv":
                        var liveItems = await FetchAllItemsAsync(client, lib.Id, "TvChannel", ct).ConfigureAwait(false);
                        channels.AddRange(liveItems.Select(i => MapChannel(i, source.Id)));
                        break;

                    // Music, Audiobooks, Photos — fetch but do not map to primary domain entities in v1
                    default:
                        _logger.LogDebug("Jellyfin library type '{Type}' not mapped to domain entities", collectionType);
                        break;
                }
            }

            _logger.LogInformation(
                "Jellyfin source {SourceId}: {Movies} movies, {Series} series, {Episodes} episodes, {Channels} channels",
                source.Id, movies.Count, series.Count, episodes.Count, channels.Count);

            return new ParseResult
            {
                Channels = channels,
                Movies = movies,
                Series = series,
            };
        }
        catch (HttpRequestException ex) when (IsConnectivityError(ex))
        {
            _logger.LogWarning("Jellyfin source {SourceId} is unreachable — returning cached data", source.Id);
            return new ParseResult { Error = $"Jellyfin server unreachable: {ex.Message}" };
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogError(ex, "Jellyfin sync failed for source {SourceId}", source.Id);
            return new ParseResult { Error = ex.Message };
        }
    }

    // ─── Fetch helpers ────────────────────────────────────────────────────────

    private static async Task<List<JellyfinItem>> FetchAllItemsAsync(
        JellyfinClient client,
        string libraryId,
        string itemType,
        CancellationToken ct)
    {
        const int PageSize = 500;
        var all = new List<JellyfinItem>();
        var startIndex = 0;

        while (true)
        {
            var page = await client.GetItemsAsync(libraryId, itemType, startIndex, PageSize, ct).ConfigureAwait(false);
            all.AddRange(page);
            if (page.Count < PageSize)
                break;
            startIndex += PageSize;
        }

        return all;
    }

    // ─── Mapping ──────────────────────────────────────────────────────────────

    private static Movie MapMovie(JellyfinItem item, int sourceId)
    {
        _ = int.TryParse(
            item.ProviderIds?.GetValueOrDefault("Tmdb"),
            out var tmdbId);

        return new Movie
        {
            Title = item.Name,
            SourceId = sourceId,
            StreamUrl = item.Path,
            Overview = item.Overview,
            Year = item.ProductionYear,
            RuntimeMinutes = item.RunTimeTicks.HasValue
                ? (int)(item.RunTimeTicks.Value / 600_000_000L)
                : null,
            TmdbId = tmdbId > 0 ? tmdbId : null,
            Thumbnail = BuildImageUrl(item),
        };
    }

    private static Series MapSeries(JellyfinItem item, int sourceId)
    {
        _ = int.TryParse(
            item.ProviderIds?.GetValueOrDefault("Tmdb"),
            out var tmdbId);

        return new Series
        {
            Title = item.Name,
            SourceId = sourceId,
            Overview = item.Overview,
            TmdbId = tmdbId > 0 ? tmdbId : null,
            Thumbnail = BuildImageUrl(item),
        };
    }

    private static Episode MapEpisode(
        JellyfinItem item,
        int sourceId,
        IReadOnlyList<JellyfinItem> seriesItems)
    {
        // Try to match seriesId — use 1 as a placeholder if not found (will be linked by SyncPipeline)
        var seriesId = 1;
        return new Episode
        {
            Title = item.Name,
            SourceId = sourceId,
            SeriesId = seriesId,
            SeasonNumber = item.ParentIndexNumber ?? 1,
            EpisodeNumber = item.IndexNumber ?? 1,
            StreamUrl = item.Path,
            Overview = item.Overview,
            RuntimeMinutes = item.RunTimeTicks.HasValue
                ? (int)(item.RunTimeTicks.Value / 600_000_000L)
                : null,
            Thumbnail = BuildImageUrl(item),
        };
    }

    private static Channel MapChannel(JellyfinItem item, int sourceId)
    {
        return new Channel
        {
            Title = item.Name,
            SourceId = sourceId,
            TvgLogo = BuildImageUrl(item),
            CatchupType = CatchupType.None,
        };
    }

    private static string? BuildImageUrl(JellyfinItem item)
    {
        if (item.ImageTags?.TryGetValue("Primary", out var tag) == true)
            return $"http://localhost:8096/Items/{item.Id}/Images/Primary?tag={tag}&maxWidth=500";
        return null;
    }

    private static bool IsConnectivityError(HttpRequestException ex)
        => ex.StatusCode is null || ex.StatusCode == HttpStatusCode.ServiceUnavailable;
}
