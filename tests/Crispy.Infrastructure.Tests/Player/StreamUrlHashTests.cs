using Crispy.Infrastructure.Player;
using FluentAssertions;
using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class StreamUrlHashTests
{
    [Fact]
    public void Compute_ReturnsSameHash_WhenCalledTwiceWithSameUrl()
    {
        var url = "http://example.com/stream";

        var first = StreamUrlHash.Compute(url);
        var second = StreamUrlHash.Compute(url);

        first.Should().Be(second);
    }

    [Fact]
    public void Compute_ReturnsDifferentHashes_WhenUrlsDiffer()
    {
        var hash1 = StreamUrlHash.Compute("http://example.com/stream1");
        var hash2 = StreamUrlHash.Compute("http://example.com/stream2");

        hash1.Should().NotBe(hash2);
    }

    [Fact]
    public void Compute_ReturnsNonNullNonEmpty_ForAnyUrl()
    {
        var result = StreamUrlHash.Compute("http://example.com/live");

        result.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public void Compute_Returns16HexCharacters_ForAnyUrl()
    {
        // Hash = first 8 bytes of SHA-256 → 16 lowercase hex chars
        var result = StreamUrlHash.Compute("http://example.com/live");

        result.Should().HaveLength(16);
        result.Should().MatchRegex("^[0-9a-f]{16}$");
    }

    [Fact]
    public void Compute_ReturnsLowercaseHex()
    {
        var result = StreamUrlHash.Compute("http://example.com/stream");

        result.Should().Be(result.ToLowerInvariant());
    }

    [Fact]
    public void Compute_DoesNotThrow_ForEmptyString()
    {
        var act = () => StreamUrlHash.Compute(string.Empty);

        act.Should().NotThrow();
    }

    [Fact]
    public void Compute_ReturnsConsistentHash_ForEmptyString()
    {
        var first = StreamUrlHash.Compute(string.Empty);
        var second = StreamUrlHash.Compute(string.Empty);

        first.Should().Be(second);
        first.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public void Compute_DifferentiatesUrlWithAndWithoutQueryParams()
    {
        var baseUrl = "http://example.com/stream";
        var urlWithParams = "http://example.com/stream?token=abc123";

        var hashBase = StreamUrlHash.Compute(baseUrl);
        var hashWithParams = StreamUrlHash.Compute(urlWithParams);

        hashBase.Should().NotBe(hashWithParams);
    }

    [Fact]
    public void Compute_DifferentQueryParams_ProduceDifferentHashes()
    {
        var url1 = "http://example.com/stream?token=abc";
        var url2 = "http://example.com/stream?token=xyz";

        StreamUrlHash.Compute(url1).Should().NotBe(StreamUrlHash.Compute(url2));
    }
}
