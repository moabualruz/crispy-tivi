using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Manages player watch history: recording, resuming, and querying in-progress content.
/// </summary>
public interface IWatchHistoryService
{
    /// <summary>
    /// Records or upserts a watch history entry.
    /// If an entry with the same Id exists, PositionMs and LastWatched are updated.
    /// </summary>
    Task RecordAsync(WatchHistoryEntry entry);

    /// <summary>
    /// Updates the playback position for an existing entry.
    /// Also refreshes LastWatched to UtcNow.
    /// </summary>
    Task UpdatePositionAsync(string id, long positionMs);

    /// <summary>
    /// Returns up to 20 in-progress items for the profile, sorted by LastWatched descending (PLR-45).
    /// In-progress: Progress > 0 AND Progress &lt; 0.95.
    /// </summary>
    Task<IReadOnlyList<WatchHistoryEntry>> GetContinueWatchingAsync(string profileId);

    /// <summary>
    /// Returns the next unwatched episode in a series for the profile (PLR-46).
    /// Finds the first episode (by SeasonNumber, EpisodeNumber) not in the completed set (Progress >= 0.95).
    /// Returns null when all episodes are watched or none exist.
    /// </summary>
    Task<WatchHistoryEntry?> GetNextUnwatchedEpisodeAsync(string seriesId, string profileId);

    /// <summary>Returns a single watch history entry by ID, or null if not found.</summary>
    Task<WatchHistoryEntry?> GetAsync(string id);

    /// <summary>Deletes a single watch history entry.</summary>
    Task DeleteAsync(string id);

    /// <summary>Clears all watch history entries for the given profile.</summary>
    Task ClearAllAsync(string profileId);

    /// <summary>
    /// Generates a deterministic ID for a stream URL (PLR-47).
    /// Algorithm: SHA-256(UTF-8(streamUrl))[0..8] hex-encoded (16 lowercase hex chars).
    /// </summary>
    string GenerateId(string streamUrl);
}
