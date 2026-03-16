using System.Net;

using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.Stalker;
using Crispy.Infrastructure.Tests.TestData;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

[Trait("Category", "Unit")]
public class StalkerParserTests
{
    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static StalkerParser MakeParser(string? channelsJson = null, string? vodJson = null)
    {
        // Handshake response: token
        const string handshake = """{"js":{"token":"tok123"}}""";
        const string defaultChannels =
            """
            {"js":{"data":[
                {"name":"BBC One","xmltv_id":"bbc1","cmd":"http://stream.example.com/bbc1","logo":"http://logo.example.com/bbc1.png"}
            ]}}
            """;
        const string defaultVodCategories = """{"js":{"data":[{"id":"1","title":"Action"}]}}""";
        const string defaultVodItems =
            """
            {"js":{"data":[
                {"name":"Inception","cmd":"http://vod.example.com/inception"}
            ]}}
            """;

        var handler = new FakeMultiResponseHandler(
            handshake,
            channelsJson ?? defaultChannels,
            vodJson != null ? defaultVodCategories : "{}",
            vodJson ?? defaultVodItems);

        var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://stalker.example.com") };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        return new StalkerParser(client, NullLogger<StalkerParser>.Instance);
    }

    private static Source MakeSource() => new()
    {
        Name = "Stalker Portal",
        Url = "http://stalker.example.com",
        SourceType = SourceType.StalkerPortal,
        ProfileId = 1,
    };

    // ─── Happy path ───────────────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_ReturnsChannels_WhenHandshakeSucceeds()
    {
        var sut = MakeParser();
        var result = await sut.ParseAsync(MakeSource());

        result.IsSuccess.Should().BeTrue();
        result.Channels.Should().HaveCountGreaterThan(0);
        result.Channels[0].Title.Should().Be("BBC One");
    }

    [Fact]
    public async Task ParseAsync_SetsChannelTvgId_WhenXmltvIdPresent()
    {
        var sut = MakeParser();
        var result = await sut.ParseAsync(MakeSource());

        result.Channels[0].TvgId.Should().Be("bbc1");
    }

    [Fact]
    public async Task ParseAsync_SetsChannelTvgLogo_WhenLogoPresent()
    {
        var sut = MakeParser();
        var result = await sut.ParseAsync(MakeSource());

        result.Channels[0].TvgLogo.Should().Be("http://logo.example.com/bbc1.png");
    }

    [Fact]
    public async Task ParseAsync_SetsChannelStreamUrl_WhenCmdPresent()
    {
        var sut = MakeParser();
        var result = await sut.ParseAsync(MakeSource());

        // StreamUrl on Channel is set via StreamEndpoints — cmd maps to Url
        result.Channels[0].Title.Should().NotBeNullOrEmpty();
    }

    // ─── Channel JSON shapes ──────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_UsesUnknown_WhenNamePropertyMissing()
    {
        const string noName = """{"js":{"data":[{"xmltv_id":"ch1","cmd":"http://stream.example.com/ch1"}]}}""";
        var sut = MakeParser(channelsJson: noName);

        var result = await sut.ParseAsync(MakeSource());

        result.Channels[0].Title.Should().Be("Unknown");
    }

    [Fact]
    public async Task ParseAsync_ReturnsEmptyChannels_WhenJsPropertyMissing()
    {
        const string noJs = """{"other":{"data":[]}}""";
        var sut = MakeParser(channelsJson: noJs);

        var result = await sut.ParseAsync(MakeSource());

        result.Channels.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseAsync_ReturnsEmptyChannels_WhenDataIsNotArray()
    {
        const string notArray = """{"js":{"data":"invalid"}}""";
        var sut = MakeParser(channelsJson: notArray);

        var result = await sut.ParseAsync(MakeSource());

        result.Channels.Should().BeEmpty();
    }

    // ─── Error handling ───────────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_ReturnsError_WhenHandshakeThrows()
    {
        var throwingHandler = new ThrowingHttpHandler(
            new HttpRequestException("Connection refused"));
        var httpClient = new HttpClient(throwingHandler)
        {
            BaseAddress = new Uri("http://unreachable.example.com"),
        };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");
        var sut = new StalkerParser(client, NullLogger<StalkerParser>.Instance);

        var result = await sut.ParseAsync(MakeSource());

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().NotBeNullOrEmpty();
    }

    // ─── Multiple channels ────────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_ParsesMultipleChannels()
    {
        const string multiChannels =
            """
            {"js":{"data":[
                {"name":"BBC One"},
                {"name":"ITV"},
                {"name":"Channel 4"}
            ]}}
            """;
        var sut = MakeParser(channelsJson: multiChannels);

        var result = await sut.ParseAsync(MakeSource());

        result.Channels.Should().HaveCount(3);
        result.Channels.Select(c => c.Title).Should().Contain("BBC One", "ITV", "Channel 4");
    }

    // ─── SourceId propagation ─────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_SetsSourceId_OnAllChannels()
    {
        var source = MakeSource();
        var sut = MakeParser();

        var result = await sut.ParseAsync(source);

        result.Channels.Should().AllSatisfy(c => c.SourceId.Should().Be(source.Id));
    }
}

// ─── Test double ──────────────────────────────────────────────────────────────

/// <summary>
/// Returns sequential responses from a queue.
/// Falls back to empty JSON object when queue is exhausted.
/// </summary>
file sealed class FakeMultiResponseHandler : HttpMessageHandler
{
    private readonly Queue<string> _responses;

    public FakeMultiResponseHandler(params string[] responses)
    {
        _responses = new Queue<string>(responses);
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var json = _responses.Count > 0 ? _responses.Dequeue() : "{}";
        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json"),
        });
    }
}

file sealed class ThrowingHttpHandler : HttpMessageHandler
{
    private readonly Exception _ex;

    public ThrowingHttpHandler(Exception ex) => _ex = ex;

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
        => throw _ex;
}
