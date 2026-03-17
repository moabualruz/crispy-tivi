using System.Threading.Channels;

using Crispy.Application.Sources;
using Crispy.Domain.Interfaces;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using TvChannel = Crispy.Domain.Entities.Channel;

namespace Crispy.Infrastructure.Sync;

/// <summary>
/// Producer-consumer sync pipeline using a bounded System.Threading.Channel.
/// Parser produces Channel entities; batch writer consumes and upserts them via EF Core.
/// Also persists VOD movies and series from ParseResult.
/// </summary>
public sealed class SyncPipeline
{
    private readonly IDbContextFactory<AppDbContext> _appFactory;
    private readonly IDbContextFactory<EpgDbContext> _epgFactory;
    private readonly IMovieRepository _movieRepository;
    private readonly ISeriesRepository _seriesRepository;
    private readonly ILogger<SyncPipeline> _logger;

    private const int ChannelCapacity = 500;
    private const int BatchSize = 500;

    /// <summary>Creates a new SyncPipeline.</summary>
    public SyncPipeline(
        IDbContextFactory<AppDbContext> appFactory,
        IDbContextFactory<EpgDbContext> epgFactory,
        IMovieRepository movieRepository,
        ISeriesRepository seriesRepository,
        ILogger<SyncPipeline> logger)
    {
        _appFactory = appFactory;
        _epgFactory = epgFactory;
        _movieRepository = movieRepository;
        _seriesRepository = seriesRepository;
        _logger = logger;
    }

    /// <summary>
    /// Runs the full sync pipeline for a source: parse → batch upsert → missed-sync tracking.
    /// </summary>
    public async Task RunAsync(Crispy.Domain.Entities.Source source, ISourceParser parser, CancellationToken ct)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        _logger.LogInformation("Starting sync for source {SourceId} ({SourceName})", source.Id, source.Name);

        var pipe = Channel.CreateBounded<TvChannel>(new BoundedChannelOptions(ChannelCapacity)
        {
            FullMode = BoundedChannelFullMode.Wait,
            SingleWriter = true,
            SingleReader = true,
        });

        var presentTvgIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        int channelCount = 0;
        ParseResult? parseResult = null;

        // Run producer and consumer concurrently
        var producer = ProduceAsync(parser, source, pipe.Writer, presentTvgIds, ct);
        var consumer = ConsumeAsync(source.Id, pipe.Reader, ct, count => channelCount += count);

        await Task.WhenAll(producer, consumer).ConfigureAwait(false);
        parseResult = producer.Result;

        // Persist VOD movies and series
        if (parseResult.Movies.Count > 0)
        {
            await _movieRepository.UpsertRangeAsync(parseResult.Movies, ct).ConfigureAwait(false);
            _logger.LogInformation("Upserted {Count} movies for source {SourceId}", parseResult.Movies.Count, source.Id);
        }

        if (parseResult.Series.Count > 0)
        {
            await _seriesRepository.UpsertRangeAsync(parseResult.Series, ct).ConfigureAwait(false);
            _logger.LogInformation("Upserted {Count} series for source {SourceId}", parseResult.Series.Count, source.Id);
        }

        // Update missed sync counts for absent channels
        await UpdateMissedSyncAsync(source.Id, presentTvgIds, ct).ConfigureAwait(false);

        sw.Stop();
        _logger.LogInformation(
            "Sync complete for source {SourceId}: {Count} channels, {MovieCount} movies, {SeriesCount} series in {Ms}ms",
            source.Id, channelCount, parseResult.Movies.Count, parseResult.Series.Count, sw.ElapsedMilliseconds);
    }

    private static async Task<ParseResult> ProduceAsync(
        ISourceParser parser,
        Crispy.Domain.Entities.Source source,
        ChannelWriter<TvChannel> writer,
        HashSet<string> presentTvgIds,
        CancellationToken ct)
    {
        ParseResult result;
        try
        {
            result = await parser.ParseAsync(source, ct).ConfigureAwait(false);

            foreach (var ch in result.Channels)
            {
                if (ch.TvgId is not null)
                    presentTvgIds.Add(ch.TvgId);

                await writer.WriteAsync(ch, ct).ConfigureAwait(false);
            }
        }
        finally
        {
            writer.Complete();
        }

        return result;
    }

    private async Task ConsumeAsync(
        int sourceId,
        ChannelReader<TvChannel> reader,
        CancellationToken ct,
        Action<int> countCallback)
    {
        var batch = new List<TvChannel>(BatchSize);

        await foreach (var ch in reader.ReadAllAsync(ct).ConfigureAwait(false))
        {
            batch.Add(ch);

            if (batch.Count >= BatchSize)
            {
                await UpsertBatchAsync(sourceId, batch, ct).ConfigureAwait(false);
                countCallback(batch.Count);
                batch.Clear();
            }
        }

        if (batch.Count > 0)
        {
            await UpsertBatchAsync(sourceId, batch, ct).ConfigureAwait(false);
            countCallback(batch.Count);
        }
    }

    private async Task UpsertBatchAsync(int sourceId, List<TvChannel> batch, CancellationToken ct)
    {
        await using var ctx = await _appFactory.CreateDbContextAsync(ct).ConfigureAwait(false);

        // Load existing channels for this source keyed by ExternalId for upsert
        var externalIds = batch
            .Where(c => c.ExternalId is not null)
            .Select(c => c.ExternalId!)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var existing = await ctx.Channels
            .Where(c => c.SourceId == sourceId && c.ExternalId != null && externalIds.Contains(c.ExternalId!))
            .ToDictionaryAsync(c => c.ExternalId!, StringComparer.OrdinalIgnoreCase, ct)
            .ConfigureAwait(false);

        // Load existing endpoints for channels we already know about
        var existingChannelIds = existing.Values.Select(c => c.Id).ToHashSet();
        var existingEndpoints = existingChannelIds.Count > 0
            ? await ctx.StreamEndpoints
                .Where(e => e.SourceId == sourceId && existingChannelIds.Contains(e.ChannelId))
                .ToDictionaryAsync(e => e.ChannelId, ct)
                .ConfigureAwait(false)
            : new Dictionary<int, Crispy.Domain.Entities.StreamEndpoint>();

        foreach (var incoming in batch)
        {
            TvChannel? existingChannel = null;

            if (incoming.ExternalId is not null)
                existing.TryGetValue(incoming.ExternalId, out existingChannel);

            if (existingChannel is null)
            {
                // New channel — EF inserts channel and cascades StreamEndpoints via navigation
                ctx.Channels.Add(incoming);
            }
            else
            {
                // Update non-user fields, preserve user preferences
                existingChannel.Title = incoming.Title;
                existingChannel.TvgName = incoming.TvgName;
                existingChannel.TvgLogo = incoming.TvgLogo;
                existingChannel.TvgChno = incoming.TvgChno;
                existingChannel.GroupName = incoming.GroupName;
                existingChannel.IsRadio = incoming.IsRadio;
                existingChannel.CatchupType = incoming.CatchupType;
                existingChannel.CatchupSource = incoming.CatchupSource;
                existingChannel.CatchupDays = incoming.CatchupDays;
                existingChannel.MissedSyncCount = 0; // reset on re-appearance
                // Preserve: IsFavorite, IsHidden, CustomSortOrder, UserAssignedNumber

                // Upsert the first endpoint from the incoming channel (one endpoint per source per channel)
                var incomingEndpoint = incoming.StreamEndpoints.FirstOrDefault();
                if (incomingEndpoint is not null && !string.IsNullOrEmpty(incomingEndpoint.Url))
                {
                    if (existingEndpoints.TryGetValue(existingChannel.Id, out var existingEndpoint))
                    {
                        // Update URL in case it changed (e.g. password rotation)
                        existingEndpoint.Url = incomingEndpoint.Url;
                        existingEndpoint.Format = incomingEndpoint.Format;
                    }
                    else
                    {
                        ctx.StreamEndpoints.Add(new Crispy.Domain.Entities.StreamEndpoint
                        {
                            ChannelId = existingChannel.Id,
                            SourceId = sourceId,
                            Url = incomingEndpoint.Url,
                            Format = incomingEndpoint.Format,
                            Priority = incomingEndpoint.Priority,
                        });
                    }
                }
            }
        }

        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }

    private async Task UpdateMissedSyncAsync(
        int sourceId,
        HashSet<string> presentTvgIds,
        CancellationToken ct)
    {
        await using var ctx = await _appFactory.CreateDbContextAsync(ct).ConfigureAwait(false);

        // Channels with a TvgId that were NOT in this sync
        var absent = await ctx.Channels
            .Where(c => c.SourceId == sourceId && c.TvgId != null && !presentTvgIds.Contains(c.TvgId!))
            .ToListAsync(ct)
            .ConfigureAwait(false);

        foreach (var ch in absent)
            ch.MissedSyncCount++;

        if (absent.Count > 0)
            await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }
}
