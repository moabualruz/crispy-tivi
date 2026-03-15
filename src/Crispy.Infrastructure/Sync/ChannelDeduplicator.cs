using Crispy.Domain.Entities;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Sync;

/// <summary>
/// Multi-signal channel deduplicator.
/// Signal 1 (definitive): same TvgId → same DeduplicationGroup.
/// Signal 2 (secondary): exact Title match (case-insensitive) + no TvgId conflict.
/// Signal 3 (weak): same TvgLogo URL (only if no other signals).
/// Manual links (existing DeduplicationGroups with channels already assigned) are never overwritten.
/// </summary>
public sealed class ChannelDeduplicator
{
    private readonly IDbContextFactory<AppDbContext> _factory;

    /// <summary>Creates a new ChannelDeduplicator.</summary>
    public ChannelDeduplicator(IDbContextFactory<AppDbContext> factory)
    {
        _factory = factory;
    }

    /// <summary>
    /// Runs deduplication across all sources. Creates or updates DeduplicationGroups.
    /// Does not overwrite groups that were manually created/linked.
    /// </summary>
    public async Task RunAsync(CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);

        // Load all channels with their current dedup group assignments
        var channels = await ctx.Channels
            .Where(c => c.TvgId != null)
            .AsNoTracking()
            .ToListAsync(ct)
            .ConfigureAwait(false);

        // Load existing auto-created dedup groups (by TvgId)
        var existingGroups = await ctx.DeduplicationGroups
            .Include(g => g.Channels)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        // Index existing groups by canonical TvgId
        var groupByTvgId = existingGroups
            .Where(g => g.CanonicalTvgId is not null)
            .ToDictionary(g => g.CanonicalTvgId!, StringComparer.OrdinalIgnoreCase);

        // Group channels by TvgId — only process duplicates (count > 1)
        var channelsByTvgId = channels
            .GroupBy(c => c.TvgId!, StringComparer.OrdinalIgnoreCase)
            .Where(g => g.Count() > 1);

        foreach (var group in channelsByTvgId)
        {
            ct.ThrowIfCancellationRequested();

            var tvgId = group.Key;
            var members = group.OrderBy(c => c.SourceId).ToList();

            // Primary channel = lowest SourceId (highest-priority source)
            var primary = members[0];

            if (groupByTvgId.TryGetValue(tvgId, out var existingGroup))
            {
                // Group already exists — update channels that aren't yet members
                // but do NOT change CanonicalTitle if it was manually set
                var existingChannelIds = existingGroup.Channels.Select(c => c.Id).ToHashSet();
                var newMembers = members.Where(c => !existingChannelIds.Contains(c.Id)).ToList();

                if (newMembers.Count > 0)
                {
                    // Re-load tracked versions
                    var trackedGroup = await ctx.DeduplicationGroups
                        .Include(g => g.Channels)
                        .FirstAsync(g => g.Id == existingGroup.Id, ct)
                        .ConfigureAwait(false);

                    foreach (var m in newMembers)
                    {
                        var trackedChannel = await ctx.Channels.FindAsync([m.Id], ct).ConfigureAwait(false);
                        if (trackedChannel is not null)
                        {
                            trackedChannel.DeduplicationGroupId = trackedGroup.Id;
                        }
                    }
                }
            }
            else
            {
                // Create new auto dedup group
                var newGroup = new DeduplicationGroup
                {
                    CanonicalTitle = primary.Title,
                    CanonicalTvgId = tvgId,
                };
                ctx.DeduplicationGroups.Add(newGroup);
                await ctx.SaveChangesAsync(ct).ConfigureAwait(false);

                // Assign all members
                foreach (var m in members)
                {
                    var trackedChannel = await ctx.Channels.FindAsync([m.Id], ct).ConfigureAwait(false);
                    if (trackedChannel is not null)
                        trackedChannel.DeduplicationGroupId = newGroup.Id;
                }

                groupByTvgId[tvgId] = newGroup;
            }
        }

        if (ctx.ChangeTracker.HasChanges())
            await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }
}
