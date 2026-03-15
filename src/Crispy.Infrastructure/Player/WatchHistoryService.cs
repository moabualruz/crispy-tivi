using System.Security.Cryptography;
using System.Text;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// SQLite-backed implementation of IWatchHistoryService.
/// Implements all PLR-44 to PLR-49 rules.
/// </summary>
public sealed class WatchHistoryService : IWatchHistoryService
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    /// <summary>Initializes a new instance of <see cref="WatchHistoryService"/>.</summary>
    public WatchHistoryService(IDbContextFactory<AppDbContext> dbFactory)
    {
        _dbFactory = dbFactory;
    }

    /// <inheritdoc />
    public string GenerateId(string streamUrl)
    {
        // PLR-47: SHA-256(UTF-8(streamUrl))[0..8] hex — 16 lowercase hex characters.
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(streamUrl));
        return Convert.ToHexString(hash)[..16].ToLower();
    }

    /// <inheritdoc />
    public async Task RecordAsync(WatchHistoryEntry entry)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var existing = await db.WatchHistoryEntries
            .FindAsync(entry.Id)
            .ConfigureAwait(false);

        if (existing is not null)
        {
            existing.PositionMs = entry.PositionMs;
            existing.LastWatched = DateTimeOffset.UtcNow;
        }
        else
        {
            db.WatchHistoryEntries.Add(entry);
        }

        await db.SaveChangesAsync().ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task UpdatePositionAsync(string id, long positionMs)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var entry = await db.WatchHistoryEntries
            .FindAsync(id)
            .ConfigureAwait(false);

        if (entry is null)
        {
            return;
        }

        entry.PositionMs = positionMs;
        entry.LastWatched = DateTimeOffset.UtcNow;

        await db.SaveChangesAsync().ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<WatchHistoryEntry>> GetContinueWatchingAsync(string profileId)
    {
        // PLR-44: in-progress = PositionMs > 0 AND DurationMs > 0 AND progress < 0.95
        // PLR-45: sorted by LastWatched desc, limit 20
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        return await db.WatchHistoryEntries
            .Where(e => e.ProfileId == profileId
                     && e.PositionMs > 0
                     && e.DurationMs > 0
                     && (double)e.PositionMs / e.DurationMs < 0.95)
            .OrderByDescending(e => e.LastWatched)
            .Take(20)
            .ToListAsync()
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<WatchHistoryEntry?> GetNextUnwatchedEpisodeAsync(string seriesId, string profileId)
    {
        // PLR-46: find first episode (ordered by SeasonNumber, EpisodeNumber) not in completed set.
        // Completed = Progress >= 0.95 (i.e., PositionMs / DurationMs >= 0.95).
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var seriesEntries = await db.WatchHistoryEntries
            .Where(e => e.SeriesId == seriesId && e.ProfileId == profileId)
            .ToListAsync()
            .ConfigureAwait(false);

        // Build completed set: episodes where progress >= 0.95
        var completedKeys = seriesEntries
            .Where(e => e.DurationMs > 0 && (double)e.PositionMs / e.DurationMs >= 0.95)
            .Select(e => (e.SeasonNumber, e.EpisodeNumber))
            .ToHashSet();

        // Find first in-progress or not-started episode ordered by season/episode
        return seriesEntries
            .Where(e => e.SeasonNumber.HasValue && e.EpisodeNumber.HasValue)
            .OrderBy(e => e.SeasonNumber)
            .ThenBy(e => e.EpisodeNumber)
            .FirstOrDefault(e => !completedKeys.Contains((e.SeasonNumber, e.EpisodeNumber)));
    }

    /// <inheritdoc />
    public async Task<WatchHistoryEntry?> GetAsync(string id)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);
        return await db.WatchHistoryEntries.FindAsync(id).ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task DeleteAsync(string id)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var entry = await db.WatchHistoryEntries.FindAsync(id).ConfigureAwait(false);
        if (entry is not null)
        {
            db.WatchHistoryEntries.Remove(entry);
            await db.SaveChangesAsync().ConfigureAwait(false);
        }
    }

    /// <inheritdoc />
    public async Task ClearAllAsync(string profileId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var entries = await db.WatchHistoryEntries
            .Where(e => e.ProfileId == profileId)
            .ToListAsync()
            .ConfigureAwait(false);

        db.WatchHistoryEntries.RemoveRange(entries);
        await db.SaveChangesAsync().ConfigureAwait(false);
    }
}
