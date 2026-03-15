using System.Net;
using System.Text;
using System.Text.RegularExpressions;

using Crispy.Infrastructure.Parsers.Stalker;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

[Trait("Category", "Unit")]
public class StalkerClientTests
{
    private static HttpClient MakeFakeClient(string defaultResponse = "{}", HttpStatusCode status = HttpStatusCode.OK)
    {
        return new HttpClient(new FakeMessageHandler(defaultResponse, status))
        {
            BaseAddress = new Uri("http://test.example.com")
        };
    }

    [Fact]
    public void Constructor_NoMac_AutoDetectsMac()
    {
        var client = new StalkerClient(MakeFakeClient(), mac: null);

        // MAC should be auto-detected (non-empty, valid format or "00:00:00:00:00:00" fallback)
        client.Mac.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public void Constructor_ExplicitMac_UsesThatMac()
    {
        var client = new StalkerClient(MakeFakeClient(), mac: "AA:BB:CC:DD:EE:FF");

        client.Mac.Should().Be("AA:BB:CC:DD:EE:FF");
    }

    // ------------------------------------------------------------------
    // MAC format validation
    // ------------------------------------------------------------------

    [Fact]
    public void Constructor_NoMac_AutoDetectedMacHasValidFormat()
    {
        var client = new StalkerClient(MakeFakeClient(), mac: null);

        // Either a real MAC (XX:XX:XX:XX:XX:XX) or the fallback "00:00:00:00:00:00"
        client.Mac.Should().MatchRegex(@"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$");
    }

    // ------------------------------------------------------------------
    // HandshakeAsync: valid token returned
    // ------------------------------------------------------------------

    [Fact]
    public async Task HandshakeAsync_ReturnsToken_WhenResponseContainsToken()
    {
        const string json = """{"js":{"token":"abc123"}}""";
        using var httpClient = new HttpClient(new FakeMessageHandler(json))
        {
            BaseAddress = new Uri("http://test.example.com")
        };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        var token = await client.HandshakeAsync();

        token.Should().Be("abc123");
    }

    // ------------------------------------------------------------------
    // HandshakeAsync: HTTP 401 → returns null
    // ------------------------------------------------------------------

    [Fact]
    public async Task HandshakeAsync_ReturnsNull_WhenServerReturns401()
    {
        using var httpClient = new HttpClient(
            new FakeMessageHandler("{}", HttpStatusCode.Unauthorized))
        {
            BaseAddress = new Uri("http://test.example.com")
        };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        var token = await client.HandshakeAsync();

        token.Should().BeNull();
    }

    // ------------------------------------------------------------------
    // HandshakeAsync: JSON missing "token" property → returns null
    // ------------------------------------------------------------------

    [Fact]
    public async Task HandshakeAsync_ReturnsNull_WhenTokenPropertyMissing()
    {
        const string json = """{"js":{"other":"value"}}""";
        using var httpClient = new HttpClient(new FakeMessageHandler(json))
        {
            BaseAddress = new Uri("http://test.example.com")
        };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        var token = await client.HandshakeAsync();

        token.Should().BeNull();
    }

    // ------------------------------------------------------------------
    // HandshakeAsync: empty JSON → returns null
    // ------------------------------------------------------------------

    [Fact]
    public async Task HandshakeAsync_ReturnsNull_WhenJsonIsEmptyObject()
    {
        using var httpClient = new HttpClient(new FakeMessageHandler("{}"))
        {
            BaseAddress = new Uri("http://test.example.com")
        };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        var token = await client.HandshakeAsync();

        token.Should().BeNull();
    }

    // ------------------------------------------------------------------
    // GetProfileAsync: triggers handshake + returns document
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetProfileAsync_ReturnsDocument_WhenServerRespondsOk()
    {
        const string json = """{"js":{"token":"t1","profile":"data"}}""";
        using var httpClient = new HttpClient(new FakeMessageHandler(json))
        {
            BaseAddress = new Uri("http://test.example.com")
        };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        // First perform handshake, then call profile
        await client.HandshakeAsync();
        var doc = await client.GetProfileAsync();

        doc.Should().NotBeNull();
    }

    // ------------------------------------------------------------------
    // DisposeAsync: does not throw
    // ------------------------------------------------------------------

    [Fact]
    public async Task DisposeAsync_DoesNotThrow_WhenCalledWithoutKeepAlive()
    {
        var client = new StalkerClient(MakeFakeClient(), mac: "AA:BB:CC:DD:EE:FF");

        var act = async () => await client.DisposeAsync();

        await act.Should().NotThrowAsync();
    }

    // ------------------------------------------------------------------
    // DisposeAsync: does not throw after keep-alive started
    // ------------------------------------------------------------------

    [Fact]
    public async Task DisposeAsync_DoesNotThrow_WhenCalledAfterKeepAliveStarted()
    {
        var client = new StalkerClient(MakeFakeClient(), mac: "AA:BB:CC:DD:EE:FF");
        await client.StartKeepAliveAsync(interval: TimeSpan.FromSeconds(10));

        var act = async () => await client.DisposeAsync();

        await act.Should().NotThrowAsync();
    }

    // ------------------------------------------------------------------
    // GetProfileAsync without prior handshake triggers auto-handshake
    // (exercises GetAuthorizedAsync "_token is null" branch)
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetProfileAsync_TriggersAutoHandshake_WhenNoTokenYet()
    {
        // Response provides a token so the authorized call can proceed
        const string json = """{"js":{"token":"auto-tok","profile":"ok"}}""";
        using var httpClient = new HttpClient(new FakeMessageHandler(json))
        {
            BaseAddress = new Uri("http://test.example.com")
        };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        // Call without any prior HandshakeAsync — should auto-handshake internally
        var doc = await client.GetProfileAsync();

        doc.Should().NotBeNull();
    }

    // ------------------------------------------------------------------
    // Keep-alive lambda actually fires at least once (covers the loop body)
    // ------------------------------------------------------------------

    [Fact]
    public async Task KeepAlive_FiresAtLeastOnce_WhenIntervalElapses()
    {
        var callCount = 0;
        // First call is handshake (auto), subsequent are keep-alive pings
        var handler = new CountingHandler(() => callCount++);
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "00:11:22:33:44:55");

        await client.StartKeepAliveAsync(interval: TimeSpan.FromMilliseconds(30));
        await Task.Delay(200); // Allow several ticks
        await client.StopKeepAliveAsync();

        callCount.Should().BeGreaterThan(0, "keep-alive should have fired at least once");
    }

    [Fact]
    public async Task KeepAlive_AfterStop_DoesNotRun()
    {
        var callCount = 0;
        var handler = new CountingHandler(() => callCount++);
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };

        var client = new StalkerClient(httpClient, mac: "00:11:22:33:44:55");

        await client.StartKeepAliveAsync(interval: TimeSpan.FromMilliseconds(50));
        await Task.Delay(30); // Less than one interval
        await client.StopKeepAliveAsync();

        var countAtStop = callCount;
        await Task.Delay(150); // Would be enough for 3 more ticks if still running

        callCount.Should().Be(countAtStop, "keep-alive should not fire after StopKeepAliveAsync");
    }

    private sealed class FakeMessageHandler : HttpMessageHandler
    {
        private readonly string _response;
        private readonly HttpStatusCode _status;

        public FakeMessageHandler(string response, HttpStatusCode status = HttpStatusCode.OK)
        {
            _response = response;
            _status = status;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(_status)
            {
                Content = new StringContent(_response, Encoding.UTF8, "application/json")
            });
        }
    }

    private sealed class CountingHandler : HttpMessageHandler
    {
        private readonly Action _onSend;

        public CountingHandler(Action onSend) => _onSend = onSend;

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            _onSend();
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{}", Encoding.UTF8, "application/json")
            });
        }
    }
}
