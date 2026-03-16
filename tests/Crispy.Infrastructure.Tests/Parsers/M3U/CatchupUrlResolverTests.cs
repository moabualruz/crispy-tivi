using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.M3U;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers.M3U;

[Trait("Category", "Unit")]
public class CatchupUrlResolverTests
{
    // Fixed reference time: 2024-06-15 10:00:00 UTC (no offset)
    private static readonly DateTimeOffset Start = new DateTimeOffset(2024, 6, 15, 10, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset End = new DateTimeOffset(2024, 6, 15, 11, 0, 0, TimeSpan.Zero);

    // ─── Append mode ──────────────────────────────────────────────────────────

    [Fact]
    public void Resolve_AppendsUtcParams_WhenTypeIsAppendAndNoQueryString()
    {
        var result = CatchupUrlResolver.Resolve("http://stream.example.com/play", CatchupType.Append, Start, End);

        var expectedUtc = Start.ToUnixTimeSeconds();
        result.Should().Be($"http://stream.example.com/play?utc={expectedUtc}&lutc={expectedUtc}");
    }

    [Fact]
    public void Resolve_AppendsWithAmpersand_WhenTypeIsAppendAndQueryStringExists()
    {
        var result = CatchupUrlResolver.Resolve("http://stream.example.com/play?token=abc", CatchupType.Append, Start, End);

        var expectedUtc = Start.ToUnixTimeSeconds();
        result.Should().Be($"http://stream.example.com/play?token=abc&utc={expectedUtc}&lutc={expectedUtc}");
    }

    // ─── Placeholder substitution ──────────────────────────────────────────────

    [Fact]
    public void Resolve_SubstitutesStartAndEnd_WhenTemplateContainsStartEnd()
    {
        var template = "http://catchup.example.com/stream?start={start}&end={end}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Be($"http://catchup.example.com/stream?start={Start.ToUnixTimeSeconds()}&end={End.ToUnixTimeSeconds()}");
    }

    [Fact]
    public void Resolve_SubstitutesDuration_WhenTemplateContainsDuration()
    {
        var template = "http://catchup.example.com/stream?duration={duration}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Contain("duration=3600");
    }

    [Fact]
    public void Resolve_SubstitutesUtcStart_WhenTemplateContainsUtcstart()
    {
        var template = "http://catchup.example.com/stream?s={utcstart}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Contain("s=20240615100000");
    }

    [Fact]
    public void Resolve_SubstitutesUtcEnd_WhenTemplateContainsUtcend()
    {
        var template = "http://catchup.example.com/stream?e={utcend}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Contain("e=20240615110000");
    }

    [Fact]
    public void Resolve_SubstitutesLutcstart_WhenTemplateContainsLutcstart()
    {
        var template = "http://catchup.example.com/?ls={lutcstart}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Contain($"ls={Start.ToUnixTimeSeconds()}");
    }

    [Fact]
    public void Resolve_SubstitutesLutcend_WhenTemplateContainsLutcend()
    {
        var template = "http://catchup.example.com/?le={lutcend}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Contain($"le={End.ToUnixTimeSeconds()}");
    }

    [Fact]
    public void Resolve_SubstitutesDateParts_WhenTemplateContainsYmdHMS()
    {
        var template = "http://catchup.example.com/{Y}/{m}/{d}/{H}/{M}/{S}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Be("http://catchup.example.com/2024/06/15/10/00/00");
    }

    [Fact]
    public void Resolve_SubstitutesPositiveOffset_WhenStartHasPositiveTimezone()
    {
        var startWithOffset = new DateTimeOffset(2024, 6, 15, 12, 0, 0, TimeSpan.FromHours(2));
        var endWithOffset = new DateTimeOffset(2024, 6, 15, 13, 0, 0, TimeSpan.FromHours(2));
        var template = "http://catchup.example.com/?offset={offset}";

        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, startWithOffset, endWithOffset);

        result.Should().Contain("offset=+2");
    }

    [Fact]
    public void Resolve_SubstitutesNegativeOffset_WhenStartHasNegativeTimezone()
    {
        var startWithOffset = new DateTimeOffset(2024, 6, 15, 5, 0, 0, TimeSpan.FromHours(-5));
        var endWithOffset = new DateTimeOffset(2024, 6, 15, 6, 0, 0, TimeSpan.FromHours(-5));
        var template = "http://catchup.example.com/?offset={offset}";

        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, startWithOffset, endWithOffset);

        result.Should().Contain("offset=-5");
    }

    [Fact]
    public void Resolve_SubstitutesZeroOffset_WhenStartIsUtc()
    {
        var template = "http://catchup.example.com/?offset={offset}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Contain("offset=+0");
    }

    [Fact]
    public void Resolve_LeavesUnknownPlaceholders_WhenTemplateHasNoMatchingTokens()
    {
        var template = "http://catchup.example.com/{unknown}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Be("http://catchup.example.com/{unknown}");
    }

    [Fact]
    public void Resolve_ReturnsTemplateUnchanged_WhenNoPlaceholders()
    {
        var template = "http://catchup.example.com/stream.m3u8";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, End);

        result.Should().Be(template);
    }

    [Fact]
    public void Resolve_SubstitutesAllPlaceholders_WhenFullTemplate()
    {
        var startUnix = Start.ToUnixTimeSeconds();
        var endUnix = End.ToUnixTimeSeconds();
        var template = "{start}|{end}|{duration}|{utcstart}|{utcend}|{lutcstart}|{lutcend}|{Y}|{m}|{d}|{H}|{M}|{S}|{offset}";

        var result = CatchupUrlResolver.Resolve(template, CatchupType.Shift, Start, End);

        result.Should().Be($"{startUnix}|{endUnix}|3600|20240615100000|20240615110000|{startUnix}|{endUnix}|2024|06|15|10|00|00|+0");
    }

    [Fact]
    public void Resolve_UsesSubstitutePlaceholders_WhenTypeIsShift()
    {
        var template = "http://catchup.example.com/?start={start}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Shift, Start, End);

        result.Should().Contain($"start={Start.ToUnixTimeSeconds()}");
    }

    [Fact]
    public void Resolve_UsesSubstitutePlaceholders_WhenTypeIsFlussonic()
    {
        var template = "http://catchup.example.com/?start={start}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Flussonic, Start, End);

        result.Should().Contain($"start={Start.ToUnixTimeSeconds()}");
    }

    [Fact]
    public void Resolve_UsesSubstitutePlaceholders_WhenTypeIsXc()
    {
        var template = "http://catchup.example.com/?start={start}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Xc, Start, End);

        result.Should().Contain($"start={Start.ToUnixTimeSeconds()}");
    }

    [Fact]
    public void Resolve_DurationIsZero_WhenStartEqualsEnd()
    {
        var template = "http://catchup.example.com/?duration={duration}";
        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, Start, Start);

        result.Should().Contain("duration=0");
    }
}
