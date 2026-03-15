using System.Threading.Channels;

using Crispy.Application.Sources;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using TvChannel = Crispy.Domain.Entities.Channel;

namespace Crispy.Infrastructure.Sync;

/// <summary>
/// Producer-consumer sync pipeline using a bounded System.Threading.Channel.
/// Parser produces Channel entities; batch writer consumes and upserts them via EF Core.
/// </summary>
public sealed class SyncPipeline
{
    private readonly IDbContextFactory<AppDbContext> _appFactory;
    private readonly IDbContextFactory<EpgDbContext> _epgFactory;
    private readonly ILogger<SyncPipeline> _logger;

    private const int ChannelCapacity = 500;
    private const int BatchSize = 500;

    /// <summary>Creates a new SyncPipeline.</summary>
    public SyncPipeline(
        IDbContextFactory<AppDbContext> appFactory,
        IDbContextFactory<EpgDbContext> epgFactory,
        ILogger<SyncPipeline> logger)
    {
        _appFactory = appFactory;
        _epgFactory = epgFactory;
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

        // Run producer and consumer concurrently
        var producer = ProduceAsync(parser, source, pipe.Writer, presentTvgIds, ct);
        var consumer = ConsumeAsync(source.Id, pipe.Reader, ct, count => channelCount += count);

        await Task.WhenAll(producer, consumer).ConfigureAwait(false);

        // Update missed sync counts for absent channels
        await UpdateMissedSyncAsync(source.Id, presentTvgIds, ct).ConfigureAwait(false);

        sw.Stop();
        _logger.LogInformation(
            "Sync complete for source {SourceId}: {Count} channels in {Ms}ms",
            source.Id, channelCount, sw.ElapsedMilliseconds);
    }

    private static async Task ProduceAsync(
        ISourceParser parser,
        Crispy.Domain.Entities.Source source,
        ChannelWriter<TvChannel> writer,
        HashSet<string> presentTvgIds,
        CancellationToken ct)
    {
        try
        {
            var result = await parser.ParseAsync(source, ct).ConfigureAwait(false);

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

        // Load existing channels for this source to do diff-based upsert
        var tvgIds = batch
            .Where(c => c.TvgId is not null)
            .Select(c => c.TvgId!)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var existing = await ctx.Channels
            .Where(c => c.SourceId == sourceId && c.TvgId != null && tvgIds.Contains(c.TvgId!))
            .ToDictionaryAsync(c => c.TvgId!, StringComparer.OrdinalIgnoreCase, ct)
            .ConfigureAwait(false);

        var titlesOfNoTvgId = batch
            .Where(c => c.TvgId is null)
            .Select(c => c.Title)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var existingByTitle = await ctx.Channels
            .Where(c => c.SourceId == sourceId && c.TvgId == null && titlesOfNoTvgId.Contains(c.Title))
            .ToDictionaryAsync(c => c.Title, StringComparer.OrdinalIgnoreCase, ct)
            .ConfigureAwait(false);

        foreach (var incoming in batch)
        {
            TvChannel? existingChannel = null;

            if (incoming.TvgId is not null)
                existing.TryGetValue(incoming.TvgId, out existingChannel);
            else
                existingByTitle.TryGetValue(incoming.Title, out existingChannel);

            if (existingChannel is null)
            {
                // New channel — insert
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
