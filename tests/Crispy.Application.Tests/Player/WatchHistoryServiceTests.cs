using System.Security.Cryptography;
using System.Text;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.Application.Tests.Player;

/// <summary>
/// Unit tests for IWatchHistoryService verifying PLR-44 to PLR-49.
/// </summary>
[Trait("Category", "Unit")]
public class WatchHistoryServiceTests
{
    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static WatchHistoryEntry MakeEntry(
        string streamUrl,
        long positionMs,
        long durationMs,
        DateTimeOffset? lastWatched = null,
        string? seriesId = null,
        int? seasonNumber = null,
        int? episodeNumber = null,
        string profileId = "profile-1")
    {
        var id = ComputeExpectedId(streamUrl);
        return new WatchHistoryEntry
        {
            Id = id,
            MediaType = seriesId is not null ? MediaType.Episode : MediaType.Movie,
            Name = "Test Content",
            StreamUrl = streamUrl,
            PositionMs = positionMs,
            DurationMs = durationMs,
            LastWatched = lastWatched ?? DateTimeOffset.UtcNow,
            SeriesId = seriesId,
            SeasonNumber = seasonNumber,
            EpisodeNumber = episodeNumber,
            DeviceId = "device-1",
            DeviceName = "Test Device",
            ProfileId = profileId,
            SourceId = "source-1",
        };
    }

    private static string ComputeExpectedId(string streamUrl)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(streamUrl));
        return Convert.ToHexString(hash)[..16].ToLower();
    }

    // NOTE: WatchHistoryService does not exist yet — these tests are RED.
    // The service will be implemented in Task 2.
    private static IWatchHistoryService CreateService()
        => throw new NotImplementedException("WatchHistoryService not yet implemented");

    // -------------------------------------------------------------------------
    // GetContinueWatching_ReturnsOnlyInProgress_ExcludesFinished
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetContinueWatching_ReturnsOnlyInProgress_ExcludesFinished()
    {
        // Arrange: one finished item (progress >= 0.95), one in-progress
        var service = CreateService();

        var finished = MakeEntry("http://stream/1", positionMs: 9500, durationMs: 10000); // 0.95 — finished
        var inProgress = MakeEntry("http://stream/2", positionMs: 5000, durationMs: 10000); // 0.50 — in-progress

        await service.RecordAsync(finished);
        await service.RecordAsync(inProgress);

        // Act
        var result = await service.GetContinueWatchingAsync("profile-1");

        // Assert
        result.Should().HaveCount(1);
        result[0].Id.Should().Be(inProgress.Id);
    }

    // -------------------------------------------------------------------------
    // GetContinueWatching_ReturnsOnlyInProgress_ExcludesNotStarted
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetContinueWatching_ReturnsOnlyInProgress_ExcludesNotStarted()
    {
        // Arrange: one not-started item (position == 0), one in-progress
        var service = CreateService();

        var notStarted = MakeEntry("http://stream/3", positionMs: 0, durationMs: 10000); // 0.0 — not started
        var inProgress = MakeEntry("http://stream/4", positionMs: 3000, durationMs: 10000); // 0.30 — in-progress

        await service.RecordAsync(notStarted);
        await service.RecordAsync(inProgress);

        // Act
        var result = await service.GetContinueWatchingAsync("profile-1");

        // Assert
        result.Should().HaveCount(1);
        result[0].Id.Should().Be(inProgress.Id);
    }

    // -------------------------------------------------------------------------
    // GetContinueWatching_LimitsTwenty_WhenMoreExist
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetContinueWatching_LimitsTwenty_WhenMoreExist()
    {
        // Arrange: 25 in-progress items
        var service = CreateService();

        for (var i = 0; i < 25; i++)
        {
            var entry = MakeEntry($"http://stream/limit-{i}", positionMs: 3000, durationMs: 10000);
            await service.RecordAsync(entry);
        }

        // Act
        var result = await service.GetContinueWatchingAsync("profile-1");

        // Assert (PLR-45: limit 20)
        result.Should().HaveCount(20);
    }

    // -------------------------------------------------------------------------
    // GetContinueWatching_SortsByLastWatchedDesc
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetContinueWatching_SortsByLastWatchedDesc()
    {
        // Arrange: items with distinct LastWatched timestamps
        var service = CreateService();

        var baseTime = new DateTimeOffset(2025, 1, 1, 0, 0, 0, TimeSpan.Zero);

        var older = MakeEntry("http://stream/old", positionMs: 3000, durationMs: 10000,
            lastWatched: baseTime.AddHours(-2));
        var newer = MakeEntry("http://stream/new", positionMs: 4000, durationMs: 10000,
            lastWatched: baseTime.AddHours(-1));
        var newest = MakeEntry("http://stream/newest", positionMs: 5000, durationMs: 10000,
            lastWatched: baseTime);

        await service.RecordAsync(older);
        await service.RecordAsync(newer);
        await service.RecordAsync(newest);

        // Act
        var result = await service.GetContinueWatchingAsync("profile-1");

        // Assert — most recent first
        result.Should().HaveCount(3);
        result[0].Id.Should().Be(newest.Id);
        result[1].Id.Should().Be(newer.Id);
        result[2].Id.Should().Be(older.Id);
    }

    // -------------------------------------------------------------------------
    // GetNextUnwatchedEpisode_ReturnsFirstUnwatched_InOrder
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetNextUnwatchedEpisode_ReturnsFirstUnwatched_InOrder()
    {
        // Arrange: S1E1 completed, S1E2 in-progress, S1E3 not started
        var service = CreateService();

        var ep1 = MakeEntry("http://stream/ep1", positionMs: 9600, durationMs: 10000,
            seriesId: "series-1", seasonNumber: 1, episodeNumber: 1); // completed
        var ep2 = MakeEntry("http://stream/ep2", positionMs: 5000, durationMs: 10000,
            seriesId: "series-1", seasonNumber: 1, episodeNumber: 2); // in-progress
        var ep3 = MakeEntry("http://stream/ep3", positionMs: 0, durationMs: 10000,
            seriesId: "series-1", seasonNumber: 1, episodeNumber: 3); // not started

        await service.RecordAsync(ep1);
        await service.RecordAsync(ep2);
        await service.RecordAsync(ep3);

        // Act: next unwatched = ep2 (first not in completed set)
        var result = await service.GetNextUnwatchedEpisodeAsync("series-1", "profile-1");

        // Assert (PLR-46: first episode not in completed set)
        result.Should().NotBeNull();
        result!.EpisodeNumber.Should().Be(2);
    }

    // -------------------------------------------------------------------------
    // GenerateHistoryId_IsSha256First8Bytes_OfStreamUrl
    // -------------------------------------------------------------------------

    [Fact]
    public void GenerateHistoryId_IsSha256First8Bytes_OfStreamUrl()
    {
        // Arrange
        var service = CreateService();
        const string streamUrl = "http://iptv.example.com/stream/ch1";

        // Act
        var id = service.GenerateId(streamUrl);

        // Assert: must match SHA-256(UTF-8(url))[0..8] hex (16 lowercase chars) — PLR-47
        var expected = ComputeExpectedId(streamUrl);
        id.Should().Be(expected);
        id.Should().HaveLength(16);
        id.Should().MatchRegex("^[0-9a-f]{16}$");
    }

    // -------------------------------------------------------------------------
    // Progress_IsPositionMs_DividedBy_DurationMs
    // -------------------------------------------------------------------------

    [Fact]
    public void Progress_IsPositionMs_DividedBy_DurationMs()
    {
        // Arrange (PLR-49: computed property on WatchHistoryEntry — no service needed)
        var entry = MakeEntry("http://stream/progress", positionMs: 3000, durationMs: 10000);

        // Act + Assert
        entry.Progress.Should().BeApproximately(0.3, precision: 0.0001);
    }
}
