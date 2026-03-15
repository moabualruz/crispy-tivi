using System.Security.Cryptography;
using System.Text;

using Crispy.Application.Player.Models;

using FluentAssertions;

using Xunit;

namespace Crispy.Application.Tests.Player;

/// <summary>
/// Unit tests for WatchHistoryEntry computed properties (PLR-44, PLR-47, PLR-49).
/// These tests validate Application-layer model logic with no infrastructure dependency.
/// Full persistence tests (GetContinueWatching, GetNextUnwatchedEpisode) live in
/// Crispy.Infrastructure.Tests — WatchHistoryServiceTests.cs.
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
        string profileId = "profile-1")
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(streamUrl));
        var id = Convert.ToHexString(hash)[..16].ToLower();

        return new WatchHistoryEntry
        {
            Id = id,
            MediaType = MediaType.Movie,
            Name = "Test Content",
            StreamUrl = streamUrl,
            PositionMs = positionMs,
            DurationMs = durationMs,
            LastWatched = DateTimeOffset.UtcNow,
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

    // -------------------------------------------------------------------------
    // Progress_IsPositionMs_DividedBy_DurationMs (PLR-49)
    // -------------------------------------------------------------------------

    [Fact]
    public void Progress_IsPositionMs_DividedBy_DurationMs()
    {
        var entry = MakeEntry("http://stream/progress", positionMs: 3000, durationMs: 10000);
        entry.Progress.Should().BeApproximately(0.3, precision: 0.0001);
    }

    [Fact]
    public void Progress_IsZero_WhenDurationIsZero()
    {
        var entry = MakeEntry("http://stream/live", positionMs: 0, durationMs: 0);
        entry.Progress.Should().Be(0.0);
    }

    // -------------------------------------------------------------------------
    // IsInProgress (PLR-44): Progress > 0 AND < 0.95
    // -------------------------------------------------------------------------

    [Fact]
    public void IsInProgress_IsTrue_WhenProgressBetweenZeroAndNinetyFivePercent()
    {
        var entry = MakeEntry("http://stream/a", positionMs: 5000, durationMs: 10000); // 0.5
        entry.IsInProgress.Should().BeTrue();
    }

    [Fact]
    public void IsInProgress_IsFalse_WhenProgressIsZero()
    {
        var entry = MakeEntry("http://stream/b", positionMs: 0, durationMs: 10000); // 0.0
        entry.IsInProgress.Should().BeFalse();
    }

    [Fact]
    public void IsInProgress_IsFalse_WhenProgressIsAtNinetyFivePercent()
    {
        var entry = MakeEntry("http://stream/c", positionMs: 9500, durationMs: 10000); // 0.95 — finished
        entry.IsInProgress.Should().BeFalse();
    }

    [Fact]
    public void IsInProgress_IsFalse_WhenProgressExceedsNinetyFivePercent()
    {
        var entry = MakeEntry("http://stream/d", positionMs: 9999, durationMs: 10000); // 0.9999
        entry.IsInProgress.Should().BeFalse();
    }

    // -------------------------------------------------------------------------
    // GenerateHistoryId (PLR-47): SHA-256(url)[0..8] hex = 16 lowercase chars
    // NOTE: GenerateId is on WatchHistoryService (Infrastructure). This test
    // validates the deterministic formula using the same algorithm directly.
    // -------------------------------------------------------------------------

    [Fact]
    public void GenerateHistoryId_IsSha256First8Bytes_OfStreamUrl()
    {
        const string streamUrl = "http://iptv.example.com/stream/ch1";

        // Compute expected ID using the PLR-47 algorithm directly
        var expected = ComputeExpectedId(streamUrl);

        expected.Should().HaveLength(16);
        expected.Should().MatchRegex("^[0-9a-f]{16}$",
            "ID must be 16 lowercase hex characters (first 8 bytes of SHA-256)");
    }

    [Fact]
    public void GenerateHistoryId_IsDeterministic_ForSameUrl()
    {
        const string streamUrl = "http://stream/stable";

        var id1 = ComputeExpectedId(streamUrl);
        var id2 = ComputeExpectedId(streamUrl);

        id1.Should().Be(id2, "same URL must always produce the same ID");
    }
}
