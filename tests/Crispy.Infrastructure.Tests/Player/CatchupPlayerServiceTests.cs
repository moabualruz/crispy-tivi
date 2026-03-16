using Crispy.Application.Player.Models;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Player;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class CatchupPlayerServiceTests
{
    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    private static CatchupPlayerService CreateSut(FakePlayerService? player = null)
    {
        player ??= new FakePlayerService();
        return new CatchupPlayerService(player, NullLogger<CatchupPlayerService>.Instance);
    }

    private static Channel MakeChannel(
        CatchupType type,
        int catchupDays = 7,
        string? catchupSource = null) =>
        new()
        {
            Title = "Test Channel",
            SourceId = 1,
            CatchupType = type,
            CatchupDays = catchupDays,
            CatchupSource = catchupSource,
        };

    // Fixed anchor: 2024-06-15 12:00:00 UTC (well in the past for all tests)
    private static readonly DateTimeOffset BaseStart =
        new(2024, 6, 15, 12, 0, 0, TimeSpan.Zero);

    private static readonly DateTimeOffset BaseEnd =
        new(2024, 6, 15, 13, 0, 0, TimeSpan.Zero); // 60-minute programme

    // ---------------------------------------------------------------
    // ResolveCatchupUrl — Xtream (CatchupType.Xc)
    // ---------------------------------------------------------------

    [Fact]
    public void ResolveCatchupUrl_XcType_ReturnsTimeshiftUrlWithStreamId()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Xc);
        const string streamUrl = "http://host:8080/live/alice/secret/12345.ts";

        var result = sut.ResolveCatchupUrl(channel, streamUrl, BaseStart, BaseEnd, "alice", "secret");

        result.Should().StartWith("http://host:8080/timeshift/alice/secret/");
        result.Should().EndWith(".ts");
        result.Should().Contain("12345");
    }

    [Fact]
    public void ResolveCatchupUrl_XcType_DurationIsInMinutesCeiling()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Xc);
        // 90 minutes + 30 seconds → ceiling = 91 minutes
        var end = BaseStart.AddMinutes(90).AddSeconds(30);
        const string streamUrl = "http://host:8080/live/u/p/99.ts";

        var result = sut.ResolveCatchupUrl(channel, streamUrl, BaseStart, end, "u", "p");

        result.Should().MatchRegex(@"/timeshift/u/p/91/");
    }

    [Fact]
    public void ResolveCatchupUrl_XcType_FallsBackToUrlSegmentsWhenCredentialsNull()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Xc);
        const string streamUrl = "http://host:8080/live/extracted_user/extracted_pass/777.ts";

        var result = sut.ResolveCatchupUrl(channel, streamUrl, BaseStart, BaseEnd, null, null);

        result.Should().Contain("/extracted_user/extracted_pass/");
        result.Should().Contain("777");
    }

    [Fact]
    public void ResolveCatchupUrl_XcType_StartUtcFormattedCorrectly()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Xc);
        const string streamUrl = "http://host/live/u/p/1.ts";

        var result = sut.ResolveCatchupUrl(channel, streamUrl, BaseStart, BaseEnd, "u", "p");

        // Expected format: yyyy-MM-dd_HH-mm-ss → 2024-06-15_12-00-00
        result.Should().Contain("2024-06-15_12-00-00");
    }

    // ---------------------------------------------------------------
    // ResolveCatchupUrl — Stalker / Append (CatchupType.Append)
    // ---------------------------------------------------------------

    [Fact]
    public void ResolveCatchupUrl_AppendType_AppendsUtcAndLutcParameters()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Append);
        const string streamUrl = "http://stalker.example.com/stream/channel1";

        var result = sut.ResolveCatchupUrl(channel, streamUrl, BaseStart, BaseEnd, null, null);

        var expectedUtc = BaseStart.ToUnixTimeSeconds();
        var expectedLutc = BaseEnd.ToUnixTimeSeconds();
        result.Should().Be($"{streamUrl}?utc={expectedUtc}&lutc={expectedLutc}");
    }

    [Fact]
    public void ResolveCatchupUrl_AppendType_UsesAmpersandWhenUrlAlreadyHasQueryString()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Append);
        const string streamUrl = "http://stalker.example.com/stream?token=abc";

        var result = sut.ResolveCatchupUrl(channel, streamUrl, BaseStart, BaseEnd, null, null);

        var expectedUtc = BaseStart.ToUnixTimeSeconds();
        result.Should().Contain($"&utc={expectedUtc}");
        result.Should().NotContain("?utc=");
    }

    // ---------------------------------------------------------------
    // ResolveCatchupUrl — Template (Default / Flussonic / Shift)
    // ---------------------------------------------------------------

    [Theory]
    [InlineData(CatchupType.Default)]
    [InlineData(CatchupType.Flussonic)]
    [InlineData(CatchupType.Shift)]
    public void ResolveCatchupUrl_TemplateType_SubstitutesStartAndEndPlaceholders(CatchupType type)
    {
        var sut = CreateSut();
        var channel = MakeChannel(type, catchupSource: "http://cdn.example.com/catchup?start={start}&end={end}");

        var result = sut.ResolveCatchupUrl(channel, "http://ignored", BaseStart, BaseEnd, null, null);

        var expectedStart = BaseStart.ToUnixTimeSeconds().ToString();
        var expectedEnd = BaseEnd.ToUnixTimeSeconds().ToString();
        result.Should().Contain($"start={expectedStart}");
        result.Should().Contain($"end={expectedEnd}");
        result.Should().NotContain("{start}");
        result.Should().NotContain("{end}");
    }

    [Fact]
    public void ResolveCatchupUrl_TemplateType_SubstitutesDurationInSeconds()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Default,
            catchupSource: "http://cdn/catchup/{duration}/stream.m3u8");

        var result = sut.ResolveCatchupUrl(channel, "http://ignored", BaseStart, BaseEnd, null, null);

        // 60-minute programme = 3600 seconds
        result.Should().Contain("/3600/");
        result.Should().NotContain("{duration}");
    }

    [Fact]
    public void ResolveCatchupUrl_FlussonicTemplate_SubstitutesUtcstartAndUtcendPlaceholders()
    {
        var sut = CreateSut();
        var channel = MakeChannel(
            CatchupType.Flussonic,
            catchupSource: "http://flussonic.example.com/video/{utcstart}-{utcend}/index.m3u8");

        var result = sut.ResolveCatchupUrl(channel, "http://ignored", BaseStart, BaseEnd, null, null);

        result.Should().Contain("20240615120000-20240615130000");
        result.Should().NotContain("{utcstart}");
        result.Should().NotContain("{utcend}");
    }

    // ---------------------------------------------------------------
    // ResolveCatchupUrl — Error / edge cases
    // ---------------------------------------------------------------

    [Fact]
    public void ResolveCatchupUrl_NoneType_ThrowsInvalidOperationException()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.None);

        var act = () => sut.ResolveCatchupUrl(channel, "http://any", BaseStart, BaseEnd, null, null);

        act.Should().Throw<InvalidOperationException>()
            .WithMessage("*no catchup support*");
    }

    [Fact]
    public void ResolveCatchupUrl_TemplateTypeWithNullCatchupSource_ThrowsInvalidOperationException()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Default, catchupSource: null);

        var act = () => sut.ResolveCatchupUrl(channel, "http://any", BaseStart, BaseEnd, null, null);

        act.Should().Throw<InvalidOperationException>();
    }

    // ---------------------------------------------------------------
    // PlayCatchupAsync — happy path
    // ---------------------------------------------------------------

    [Fact]
    public async Task PlayCatchupAsync_AppendChannel_CallsPlayerWithUtcQueryParams()
    {
        var player = new FakePlayerService();
        var sut = CreateSut(player);

        var programmeStart = DateTimeOffset.UtcNow.AddHours(-2);
        var programmeEnd = programmeStart.AddHours(1);
        var channel = MakeChannel(CatchupType.Append, catchupDays: 7);

        await sut.PlayCatchupAsync(channel, "http://stalker.example.com/ch1",
            programmeStart, programmeEnd);

        player.PlayCallCount.Should().Be(1);
        player.LastPlayRequest.Should().NotBeNull();
        player.LastPlayRequest!.Url.Should().Contain("utc=");
        player.LastPlayRequest.Url.Should().Contain("lutc=");
        player.LastPlayRequest.ContentType.Should().Be(PlaybackContentType.LiveTv);
        player.LastPlayRequest.Title.Should().Be("Test Channel");
    }

    [Fact]
    public async Task PlayCatchupAsync_XcChannel_PassesTimeshiftUrlToPlayer()
    {
        var player = new FakePlayerService();
        var sut = CreateSut(player);

        var programmeStart = DateTimeOffset.UtcNow.AddHours(-3);
        var programmeEnd = programmeStart.AddHours(1);
        var channel = MakeChannel(CatchupType.Xc, catchupDays: 7);

        await sut.PlayCatchupAsync(channel, "http://host:8080/live/u/p/555.ts",
            programmeStart, programmeEnd, "u", "p");

        player.PlayCallCount.Should().Be(1);
        player.LastPlayRequest!.Url.Should().Contain("/timeshift/");
    }

    [Fact]
    public async Task PlayCatchupAsync_ResumeAtIsZero()
    {
        var player = new FakePlayerService();
        var sut = CreateSut(player);

        var programmeStart = DateTimeOffset.UtcNow.AddHours(-1);
        var programmeEnd = programmeStart.AddMinutes(30);
        var channel = MakeChannel(CatchupType.Append, catchupDays: 7);

        await sut.PlayCatchupAsync(channel, "http://stalker/ch", programmeStart, programmeEnd);

        player.LastPlayRequest!.ResumeAt.Should().Be(TimeSpan.Zero);
    }

    // ---------------------------------------------------------------
    // PlayCatchupAsync — eligibility guard (PLR-36)
    // ---------------------------------------------------------------

    [Fact]
    public async Task PlayCatchupAsync_FutureProgramme_ThrowsInvalidOperationException()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Append, catchupDays: 7);

        var futureStart = DateTimeOffset.UtcNow.AddHours(1);
        var futureEnd = futureStart.AddHours(1);

        var act = async () => await sut.PlayCatchupAsync(
            channel, "http://any", futureStart, futureEnd);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*not started yet*");
    }

    [Fact]
    public async Task PlayCatchupAsync_ProgrammeOutsideCatchupWindow_ThrowsInvalidOperationException()
    {
        var sut = CreateSut();
        var channel = MakeChannel(CatchupType.Append, catchupDays: 3);

        // 10 days ago — outside 3-day window
        var oldStart = DateTimeOffset.UtcNow.AddDays(-10);
        var oldEnd = oldStart.AddHours(1);

        var act = async () => await sut.PlayCatchupAsync(
            channel, "http://any", oldStart, oldEnd);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("*catchup window*");
    }

    [Fact]
    public async Task PlayCatchupAsync_EligibleProgramme_DoesNotThrow()
    {
        var player = new FakePlayerService();
        var sut = CreateSut(player);
        var channel = MakeChannel(CatchupType.Append, catchupDays: 7);

        var recentStart = DateTimeOffset.UtcNow.AddHours(-4);
        var recentEnd = recentStart.AddHours(1);

        var act = async () => await sut.PlayCatchupAsync(
            channel, "http://stalker/ch", recentStart, recentEnd);

        await act.Should().NotThrowAsync();
    }
}
