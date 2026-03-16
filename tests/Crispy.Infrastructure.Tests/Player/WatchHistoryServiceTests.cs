using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Player;

using FluentAssertions;

using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

/// <summary>
/// Integration tests for WatchHistoryService — validates all PLR-44 to PLR-49 rules
/// using an EF Core in-memory database per test class instance.
/// </summary>
[Trait("Category", "Unit")]
public class WatchHistoryServiceTests : IDisposable
{
    private readonly AppDbContext _db;
    private readonly IWatchHistoryService _service;

    private readonly DbContextOptions<AppDbContext> _options;

    public WatchHistoryServiceTests()
    {
        _options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        // Keep one context alive so the in-memory database is not GC'd between calls
        _db = new AppDbContext(_options);
        var factory = new OptionsDbContextFactory(_options);
        _service = new WatchHistoryService(factory);
    }

    public void Dispose() => _db.Dispose();

    // ─── Helpers ──────────────────────────────────────────────────────────────

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
        var id = ComputeId(streamUrl);
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

    private static string ComputeId(string streamUrl)
    {
        var hash = System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(streamUrl));
        return Convert.ToHexString(hash)[..16].ToLower();
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    /// <summary>PLR-44 + PLR-45: finished items excluded (progress >= 0.95).</summary>
    [Fact]
    public async Task GetContinueWatching_ReturnsOnlyInProgress_ExcludesFinished()
    {
        var finished = MakeEntry("http://stream/1", positionMs: 9500, durationMs: 10000); // 0.95
        var inProgress = MakeEntry("http://stream/2", positionMs: 5000, durationMs: 10000); // 0.50

        await _service.RecordAsync(finished);
        await _service.RecordAsync(inProgress);

        var result = await _service.GetContinueWatchingAsync("profile-1");

        result.Should().HaveCount(1);
        result[0].Id.Should().Be(inProgress.Id);
    }

    /// <summary>PLR-44 + PLR-45: not-started items excluded (progress == 0).</summary>
    [Fact]
    public async Task GetContinueWatching_ReturnsOnlyInProgress_ExcludesNotStarted()
    {
        var notStarted = MakeEntry("http://stream/3", positionMs: 0, durationMs: 10000); // 0.0
        var inProgress = MakeEntry("http://stream/4", positionMs: 3000, durationMs: 10000); // 0.30

        await _service.RecordAsync(notStarted);
        await _service.RecordAsync(inProgress);

        var result = await _service.GetContinueWatchingAsync("profile-1");

        result.Should().HaveCount(1);
        result[0].Id.Should().Be(inProgress.Id);
    }

    /// <summary>PLR-45: result capped at 20 items.</summary>
    [Fact]
    public async Task GetContinueWatching_LimitsTwenty_WhenMoreExist()
    {
        for (var i = 0; i < 25; i++)
        {
            var entry = MakeEntry($"http://stream/limit-{i}", positionMs: 3000, durationMs: 10000);
            await _service.RecordAsync(entry);
        }

        var result = await _service.GetContinueWatchingAsync("profile-1");

        result.Should().HaveCount(20);
    }

    /// <summary>PLR-45: results sorted by LastWatched descending.</summary>
    [Fact]
    public async Task GetContinueWatching_SortsByLastWatchedDesc()
    {
        var baseTime = new DateTimeOffset(2025, 1, 1, 0, 0, 0, TimeSpan.Zero);

        var older = MakeEntry("http://stream/old", positionMs: 3000, durationMs: 10000,
            lastWatched: baseTime.AddHours(-2));
        var newer = MakeEntry("http://stream/new", positionMs: 4000, durationMs: 10000,
            lastWatched: baseTime.AddHours(-1));
        var newest = MakeEntry("http://stream/newest", positionMs: 5000, durationMs: 10000,
            lastWatched: baseTime);

        await _service.RecordAsync(older);
        await _service.RecordAsync(newer);
        await _service.RecordAsync(newest);

        var result = await _service.GetContinueWatchingAsync("profile-1");

        result.Should().HaveCount(3);
        result[0].Id.Should().Be(newest.Id);
        result[1].Id.Should().Be(newer.Id);
        result[2].Id.Should().Be(older.Id);
    }

    /// <summary>PLR-46: returns first episode not in completed set, by season/episode order.</summary>
    [Fact]
    public async Task GetNextUnwatchedEpisode_ReturnsFirstUnwatched_InOrder()
    {
        var ep1 = MakeEntry("http://stream/ep1", positionMs: 9600, durationMs: 10000,
            seriesId: "series-1", seasonNumber: 1, episodeNumber: 1); // completed (>= 0.95)
        var ep2 = MakeEntry("http://stream/ep2", positionMs: 5000, durationMs: 10000,
            seriesId: "series-1", seasonNumber: 1, episodeNumber: 2); // in-progress
        var ep3 = MakeEntry("http://stream/ep3", positionMs: 0, durationMs: 10000,
            seriesId: "series-1", seasonNumber: 1, episodeNumber: 3); // not started

        await _service.RecordAsync(ep1);
        await _service.RecordAsync(ep2);
        await _service.RecordAsync(ep3);

        var result = await _service.GetNextUnwatchedEpisodeAsync("series-1", "profile-1");

        result.Should().NotBeNull();
        result!.EpisodeNumber.Should().Be(2);
    }

    /// <summary>PLR-47: GenerateId produces SHA-256(url)[0..8] hex = 16 lowercase chars.</summary>
    [Fact]
    public void GenerateHistoryId_IsSha256First8Bytes_OfStreamUrl()
    {
        const string streamUrl = "http://iptv.example.com/stream/ch1";

        var id = _service.GenerateId(streamUrl);
        var expected = ComputeId(streamUrl);

        id.Should().Be(expected);
        id.Should().HaveLength(16);
        id.Should().MatchRegex("^[0-9a-f]{16}$");
    }

    // ─── GetAsync ─────────────────────────────────────────────────────────────

    [Fact]
    public async Task GetAsync_ReturnsEntry_WhenItExists()
    {
        var entry = MakeEntry("http://stream/get-1", positionMs: 4000, durationMs: 10000);
        await _service.RecordAsync(entry);

        var result = await _service.GetAsync(entry.Id);

        result.Should().NotBeNull();
        result!.Id.Should().Be(entry.Id);
        result.StreamUrl.Should().Be(entry.StreamUrl);
    }

    [Fact]
    public async Task GetAsync_ReturnsNull_WhenIdDoesNotExist()
    {
        var result = await _service.GetAsync("nonexistent-id");

        result.Should().BeNull();
    }

    // ─── DeleteAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task DeleteAsync_RemovesEntry_WhenItExists()
    {
        var entry = MakeEntry("http://stream/del-1", positionMs: 3000, durationMs: 10000);
        await _service.RecordAsync(entry);

        await _service.DeleteAsync(entry.Id);

        var result = await _service.GetAsync(entry.Id);
        result.Should().BeNull();
    }

    [Fact]
    public async Task DeleteAsync_DoesNotThrow_WhenIdDoesNotExist()
    {
        var act = async () => await _service.DeleteAsync("nonexistent-id");

        await act.Should().NotThrowAsync();
    }

    // ─── UpdatePositionAsync ──────────────────────────────────────────────────

    [Fact]
    public async Task UpdatePositionAsync_UpdatesPosition_WhenEntryExists()
    {
        var entry = MakeEntry("http://stream/upd-1", positionMs: 1000, durationMs: 10000);
        await _service.RecordAsync(entry);

        await _service.UpdatePositionAsync(entry.Id, 7500);

        var result = await _service.GetAsync(entry.Id);
        result.Should().NotBeNull();
        result!.PositionMs.Should().Be(7500);
    }

    [Fact]
    public async Task UpdatePositionAsync_DoesNotThrow_WhenIdDoesNotExist()
    {
        var act = async () => await _service.UpdatePositionAsync("nonexistent-id", 9999);

        await act.Should().NotThrowAsync();
    }

    // ─── ClearAllAsync ────────────────────────────────────────────────────────

    [Fact]
    public async Task ClearAllAsync_RemovesAllEntriesForProfile()
    {
        await _service.RecordAsync(MakeEntry("http://stream/clear-1", positionMs: 3000, durationMs: 10000, profileId: "profile-1"));
        await _service.RecordAsync(MakeEntry("http://stream/clear-2", positionMs: 4000, durationMs: 10000, profileId: "profile-1"));

        await _service.ClearAllAsync("profile-1");

        var result = await _service.GetContinueWatchingAsync("profile-1");
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task ClearAllAsync_OnlyRemovesTargetProfile_LeavingOtherProfilesIntact()
    {
        await _service.RecordAsync(MakeEntry("http://stream/pA-1", positionMs: 3000, durationMs: 10000, profileId: "profile-A"));
        await _service.RecordAsync(MakeEntry("http://stream/pB-1", positionMs: 3000, durationMs: 10000, profileId: "profile-B"));

        await _service.ClearAllAsync("profile-A");

        var resultB = await _service.GetContinueWatchingAsync("profile-B");
        resultB.Should().HaveCount(1, "profile-B entries must not be affected by clearing profile-A");
    }

    [Fact]
    public async Task ClearAllAsync_DoesNotThrow_WhenProfileHasNoEntries()
    {
        var act = async () => await _service.ClearAllAsync("empty-profile");

        await act.Should().NotThrowAsync();
    }

    // ─── IDbContextFactory backed by options (creates a fresh instance per call) ──

    private sealed class OptionsDbContextFactory : IDbContextFactory<AppDbContext>
    {
        private readonly DbContextOptions<AppDbContext> _options;
        public OptionsDbContextFactory(DbContextOptions<AppDbContext> options) => _options = options;
        public AppDbContext CreateDbContext() => new(_options);
        public Task<AppDbContext> CreateDbContextAsync(CancellationToken ct = default)
            => Task.FromResult(new AppDbContext(_options));
    }
}
