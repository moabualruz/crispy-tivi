using System.Net;
using System.Text;

using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.Stalker;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers.Stalker;

[Trait("Category", "Unit")]
public sealed class StalkerParserTests
{
    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static Source MakeSource() => new()
    {
        Id = 7,
        Name = "Test Stalker",
        Url = "http://stalker.test",
        SourceType = SourceType.StalkerPortal,
    };

    /// <summary>
    /// Minimal fake HTTP handler — maps URL substrings to response bodies.
    /// </summary>
    private sealed class FakeHandler : HttpMessageHandler
    {
        private readonly List<(string Contains, HttpStatusCode Status, string Body)> _rules = [];

        public FakeHandler WithResponse(string urlContains, string jsonBody, HttpStatusCode status = HttpStatusCode.OK)
        {
            _rules.Add((urlContains, status, jsonBody));
            return this;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var url = request.RequestUri?.ToString() ?? "";
            foreach (var (contains, status, body) in _rules)
            {
                if (url.Contains(contains, StringComparison.OrdinalIgnoreCase))
                    return Task.FromResult(new HttpResponseMessage(status)
                    {
                        Content = new StringContent(body, Encoding.UTF8, "application/json"),
                    });
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound)
            {
                Content = new StringContent("{}", Encoding.UTF8, "application/json"),
            });
        }
    }

    private static (StalkerParser Parser, FakeHandler Handler) Build(Action<FakeHandler>? configure = null)
    {
        var handler = new FakeHandler();
        configure?.Invoke(handler);

        var http = new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") };
        var client = new StalkerClient(http, mac: "AA:BB:CC:DD:EE:FF");
        var parser = new StalkerParser(client, NullLogger<StalkerParser>.Instance);
        return (parser, handler);
    }

    // -----------------------------------------------------------------------
    // Handshake / token extraction
    // -----------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_ReturnsChannels_WhenHandshakeAndChannelListSucceed()
    {
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok-abc""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[
                {""id"":""1"",""name"":""Channel One"",""cmd"":""http://s/1"",""xmltv_id"":""ch1""},
                {""id"":""2"",""name"":""Channel Two"",""cmd"":""http://s/2""}
            ]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Error.Should().BeNull();
        result.Channels.Should().HaveCount(2);
        result.Channels[0].Title.Should().Be("Channel One");
        result.Channels[0].TvgId.Should().Be("ch1");
        result.Channels[1].Title.Should().Be("Channel Two");
        result.Channels[1].TvgId.Should().BeNull();

        // Each channel with a cmd field gets a StreamEndpoint
        result.StreamEndpoints.Should().HaveCount(2);
        result.StreamEndpoints[0].Url.Should().Be("http://s/1");
        result.StreamEndpoints[1].Url.Should().Be("http://s/2");
    }

    [Fact]
    public async Task ParseAsync_SetsSourceId_OnEachChannel()
    {
        var source = MakeSource();
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[
                {""id"":""1"",""name"":""My Channel""}
            ]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(source);

        result.Channels.Should().ContainSingle()
            .Which.SourceId.Should().Be(source.Id);
    }

    [Fact]
    public async Task ParseAsync_UsesUnknown_WhenChannelNameMissing()
    {
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[{""id"":""1""}]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Channels.Should().ContainSingle()
            .Which.Title.Should().Be("Unknown");
    }

    [Fact]
    public async Task ParseAsync_SetsStreamEndpointUrl_FromCmdField()
    {
        var source = MakeSource();
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[
                {""id"":""5"",""name"":""Sport"",""cmd"":""http://portal.test/live/5""}
            ]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(source);

        result.Channels.Should().ContainSingle();
        result.StreamEndpoints.Should().ContainSingle()
            .Which.Url.Should().Be("http://portal.test/live/5");
        result.StreamEndpoints[0].SourceId.Should().Be(source.Id);
    }

    [Fact]
    public async Task ParseAsync_OmitsStreamEndpoint_WhenCmdFieldAbsent()
    {
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[
                {""id"":""1"",""name"":""No Cmd Channel""}
            ]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Channels.Should().ContainSingle();
        result.StreamEndpoints.Should().BeEmpty();
    }

    // -----------------------------------------------------------------------
    // Channel list JSON shape variants
    // -----------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_ReturnsEmpty_WhenChannelListIsNull()
    {
        // Handshake succeeds but channel endpoint returns 404
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            // get_all_channels intentionally not registered → falls through to 404
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Error.Should().BeNull();
        result.Channels.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseAsync_ReturnsEmpty_WhenChannelDataIsNotArray()
    {
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":null}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Error.Should().BeNull();
        result.Channels.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseAsync_HandlesChannelArrayAtJsRoot_WhenNoDataProperty()
    {
        // Some portals return js as a bare array rather than { data: [...] }
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":[{""id"":""1"",""name"":""Bare Channel""}]}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[]}}");
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Channels.Should().ContainSingle()
            .Which.Title.Should().Be("Bare Channel");
    }

    // -----------------------------------------------------------------------
    // VOD (movies)
    // -----------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_ReturnsMovies_WhenVodCategoriesAndListSucceed()
    {
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[{""id"":""cat1"",""title"":""Action""}]}}");
            h.WithResponse("action=get_ordered_list", @"{""js"":{""data"":[
                {""id"":""m1"",""name"":""Movie Alpha""},
                {""id"":""m2"",""name"":""Movie Beta""}
            ]}}");
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Movies.Should().HaveCount(2);
        result.Movies[0].Title.Should().Be("Movie Alpha");
        result.Movies[1].Title.Should().Be("Movie Beta");
    }

    [Fact]
    public async Task ParseAsync_SetsSourceId_OnEachMovie()
    {
        var source = MakeSource();
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[{""id"":""cat1""}]}}");
            h.WithResponse("action=get_ordered_list", @"{""js"":{""data"":[{""id"":""m1"",""name"":""Film""}]}}");
        });

        var result = await parser.ParseAsync(source);

        result.Movies.Should().ContainSingle()
            .Which.SourceId.Should().Be(source.Id);
    }

    [Fact]
    public async Task ParseAsync_SkipsVodCategory_WhenGetVodListReturnsNull()
    {
        var (parser, _) = Build(h =>
        {
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");
            h.WithResponse("action=get_all_channels", @"{""js"":{""data"":[]}}");
            h.WithResponse("action=get_categories", @"{""js"":{""data"":[{""id"":""catX""}]}}");
            // get_ordered_list not registered → 404 → GetVodListAsync returns null → skipped
        });

        var result = await parser.ParseAsync(MakeSource());

        result.Error.Should().BeNull();
        result.Movies.Should().BeEmpty();
    }

    // -----------------------------------------------------------------------
    // Error / failure paths
    // -----------------------------------------------------------------------

    [Fact]
    public async Task ParseAsync_ReturnsError_WhenHandshakeThrows()
    {
        // Handler throws on every request
        var handler = new ThrowingHandler();
        var http = new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") };
        var client = new StalkerClient(http, mac: "AA:BB:CC:DD:EE:FF");
        var parser = new StalkerParser(client, NullLogger<StalkerParser>.Instance);

        var result = await parser.ParseAsync(MakeSource());

        result.Error.Should().NotBeNull();
        result.Channels.Should().BeEmpty();
        result.Movies.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseAsync_ReturnsError_WhenCancelled()
    {
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        var (parser, _) = Build(h =>
            h.WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}"));

        var result = await parser.ParseAsync(MakeSource(), cts.Token);

        result.Error.Should().NotBeNull();
    }

    // -----------------------------------------------------------------------
    // StalkerClient: HandshakeAsync
    // -----------------------------------------------------------------------

    [Fact]
    public async Task HandshakeAsync_ReturnsToken_WhenPortalRespondsWithToken()
    {
        var handler = new FakeHandler()
            .WithResponse("action=handshake", @"{""js"":{""token"":""secret-tok""}}");

        await using var client = new StalkerClient(
            new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") },
            mac: "AA:BB:CC:DD:EE:FF");

        var token = await client.HandshakeAsync();

        token.Should().Be("secret-tok");
    }

    [Fact]
    public async Task HandshakeAsync_ReturnsNull_WhenPortalReturnsNonSuccess()
    {
        var handler = new FakeHandler()
            .WithResponse("action=handshake", "{}", HttpStatusCode.Unauthorized);

        await using var client = new StalkerClient(
            new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") },
            mac: "AA:BB:CC:DD:EE:FF");

        var token = await client.HandshakeAsync();

        token.Should().BeNull();
    }

    [Fact]
    public async Task HandshakeAsync_ReturnsNull_WhenResponseHasNoTokenProperty()
    {
        var handler = new FakeHandler()
            .WithResponse("action=handshake", @"{""js"":{""other"":""value""}}");

        await using var client = new StalkerClient(
            new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") },
            mac: "AA:BB:CC:DD:EE:FF");

        var token = await client.HandshakeAsync();

        token.Should().BeNull();
    }

    // -----------------------------------------------------------------------
    // StalkerClient: MAC address
    // -----------------------------------------------------------------------

    [Fact]
    public async Task StalkerClient_UsesProvidedMac_WhenMacSupplied()
    {
        const string mac = "11:22:33:44:55:66";
        var handler = new FakeHandler();
        await using var client = new StalkerClient(
            new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") },
            mac: mac);

        client.Mac.Should().Be(mac);
    }

    [Fact]
    public async Task StalkerClient_UsesFallbackMac_WhenNullMacSupplied()
    {
        var handler = new FakeHandler();
        await using var client = new StalkerClient(
            new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") },
            mac: null);

        // Either auto-detected or fallback — must be non-empty and colon-separated
        client.Mac.Should().NotBeNullOrWhiteSpace();
        client.Mac.Should().MatchRegex(@"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$");
    }

    // -----------------------------------------------------------------------
    // StalkerClient: keep-alive lifecycle
    // -----------------------------------------------------------------------

    [Fact]
    public async Task StartKeepAliveAsync_ThenStop_DoesNotThrow()
    {
        var handler = new FakeHandler()
            .WithResponse("action=handshake", @"{""js"":{""token"":""tok""}}");

        await using var client = new StalkerClient(
            new HttpClient(handler) { BaseAddress = new Uri("http://stalker.test") },
            mac: "AA:BB:CC:DD:EE:FF");

        await client.HandshakeAsync();

        Func<Task> act = async () =>
        {
            await client.StartKeepAliveAsync(TimeSpan.FromMilliseconds(50));
            await Task.Delay(30);
            await client.StopKeepAliveAsync();
        };

        await act.Should().NotThrowAsync();
    }

    // -----------------------------------------------------------------------
    // Inner helpers
    // -----------------------------------------------------------------------

    private sealed class ThrowingHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromException<HttpResponseMessage>(new HttpRequestException("network down"));
    }
}
