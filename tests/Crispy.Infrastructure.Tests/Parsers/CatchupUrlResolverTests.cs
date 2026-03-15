using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.M3U;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

public class CatchupUrlResolverTests
{
    [Fact]
    public void Resolve_AllPlaceholders_ReplacedCorrectly()
    {
        var start = new DateTimeOffset(2024, 3, 15, 14, 30, 0, TimeSpan.FromHours(1));
        var end = new DateTimeOffset(2024, 3, 15, 15, 30, 0, TimeSpan.FromHours(1));

        // UTC start = 13:30:00, UTC end = 14:30:00
        var startUtc = start.UtcDateTime;

        const string template =
            "https://tv.example.com/play?start={start}&end={end}&dur={duration}" +
            "&utcstart={utcstart}&utcend={utcend}" +
            "&lutcstart={lutcstart}&lutcend={lutcend}" +
            "&Y={Y}&m={m}&d={d}&H={H}&M={M}&S={S}&offset={offset}";

        var result = CatchupUrlResolver.Resolve(template, CatchupType.Default, start, end);

        // {start} = Unix timestamp of start in local tz
        result.Should().Contain($"start={((DateTimeOffset)start).ToUnixTimeSeconds()}");
        result.Should().Contain($"end={((DateTimeOffset)end).ToUnixTimeSeconds()}");
        result.Should().Contain("dur=3600");
        result.Should().Contain($"utcstart={startUtc:yyyyMMddHHmmss}");
        result.Should().Contain("Y=2024");
        result.Should().Contain("m=03");
        result.Should().Contain("d=15");
    }

    [Fact]
    public void Resolve_AppendType_AppendsUtcParam()
    {
        var start = new DateTimeOffset(2024, 3, 15, 14, 0, 0, TimeSpan.Zero);
        var end = start.AddHours(1);
        const string template = "https://stream.example.com/live";

        var result = CatchupUrlResolver.Resolve(template, CatchupType.Append, start, end);

        result.Should().Contain("utc=");
        result.Should().StartWith("https://stream.example.com/live");
    }
}
