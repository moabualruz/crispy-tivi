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

    // ------------------------------------------------------------------
    // GetChannelsAsync — returns JsonDocument when authorised
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetChannelsAsync_ReturnsDocument_WhenAuthorised()
    {
        const string handshake = """{"js":{"token":"tok"}}""";
        const string channels = """{"js":{"data":[{"name":"BBC One"}]}}""";
        var responses = new Queue<string>(new[] { handshake, channels });

        var handler = new QueuedHandler(responses);
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        await client.HandshakeAsync();
        using var doc = await client.GetChannelsAsync();

        doc.Should().NotBeNull();
    }

    // ------------------------------------------------------------------
    // GetVodCategoriesAsync — returns document with categories
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetVodCategoriesAsync_ReturnsDocument_WhenAuthorised()
    {
        const string handshake = """{"js":{"token":"tok"}}""";
        const string categories = """{"js":{"data":[{"id":"1","title":"Action"}]}}""";
        var responses = new Queue<string>(new[] { handshake, categories });

        var handler = new QueuedHandler(responses);
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        await client.HandshakeAsync();
        using var doc = await client.GetVodCategoriesAsync();

        doc.Should().NotBeNull();
    }

    // ------------------------------------------------------------------
    // GetVodListAsync — returns document with VOD items
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetVodListAsync_ReturnsDocument_WhenAuthorised()
    {
        const string handshake = """{"js":{"token":"tok"}}""";
        const string vodList = """{"js":{"data":[{"name":"Inception","cmd":"http://vod.example.com/inception"}]}}""";
        var responses = new Queue<string>(new[] { handshake, vodList });

        var handler = new QueuedHandler(responses);
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        await client.HandshakeAsync();
        using var doc = await client.GetVodListAsync("1", page: 1);

        doc.Should().NotBeNull();
    }

    // ------------------------------------------------------------------
    // GetVodListAsync — null when server returns 401
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetVodListAsync_ReturnsNull_WhenServerReturns401()
    {
        // Handshake succeeds, subsequent auth request returns 401
        const string handshake = """{"js":{"token":"tok"}}""";
        var responses = new Queue<(string, HttpStatusCode)>(new[]
        {
            (handshake, HttpStatusCode.OK),
            ("{}", HttpStatusCode.Unauthorized),
        });

        var handler = new StatusQueuedHandler(responses);
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        await client.HandshakeAsync();
        using var doc = await client.GetVodListAsync("1");

        doc.Should().BeNull();
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

    private sealed class QueuedHandler : HttpMessageHandler
    {
        private readonly Queue<string> _responses;

        public QueuedHandler(Queue<string> responses) => _responses = responses;

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var json = _responses.Count > 0 ? _responses.Dequeue() : "{}";
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json"),
            });
        }
    }

    // ------------------------------------------------------------------
    // GetChannelsAsync — returns null when server returns 401
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetChannelsAsync_ReturnsNull_WhenServerReturns401()
    {
        const string handshake = """{"js":{"token":"tok"}}""";
        var responses = new Queue<(string, HttpStatusCode)>(new[]
        {
            (handshake, HttpStatusCode.OK),
            ("{}", HttpStatusCode.Unauthorized),
        });

        var handler = new StatusQueuedHandler(responses);
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        await client.HandshakeAsync();
        using var doc = await client.GetChannelsAsync();

        doc.Should().BeNull();
    }

    // ------------------------------------------------------------------
    // GetVodCategoriesAsync — returns null when server returns 404
    // ------------------------------------------------------------------

    [Fact]
    public async Task GetVodCategoriesAsync_ReturnsNull_WhenServerReturnsError()
    {
        const string handshake = """{"js":{"token":"tok"}}""";
        var responses = new Queue<(string, HttpStatusCode)>(new[]
        {
            (handshake, HttpStatusCode.OK),
            ("{}", HttpStatusCode.NotFound),
        });

        var handler = new StatusQueuedHandler(responses);
        using var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "AA:BB:CC:DD:EE:FF");

        await client.HandshakeAsync();
        using var doc = await client.GetVodCategoriesAsync();

        doc.Should().BeNull();
    }

    // ------------------------------------------------------------------
    // Keep-alive: exception other than OCE is silently swallowed
    // ------------------------------------------------------------------

    [Fact]
    public async Task KeepAlive_SwallowsNonOceExceptions_AndContinues()
    {
        // Handler throws on the first keep-alive ping (after token auto-handshake)
        var callCount = 0;
        var throwingHandler = new ThrowingOnPingHandler(() => callCount++);
        using var httpClient = new HttpClient(throwingHandler) { BaseAddress = new Uri("http://test.example.com") };
        var client = new StalkerClient(httpClient, mac: "00:11:22:33:44:55");

        // Should not throw — the catch block in the loop body swallows non-OCE exceptions
        var act = async () =>
        {
            await client.StartKeepAliveAsync(interval: TimeSpan.FromMilliseconds(20));
            await Task.Delay(120);
            await client.StopKeepAliveAsync();
        };

        await act.Should().NotThrowAsync();
        callCount.Should().BeGreaterThan(0, "the loop should have attempted at least one ping");
    }

    // ------------------------------------------------------------------
    // StopKeepAliveAsync when not started — no-op, does not throw
    // ------------------------------------------------------------------

    [Fact]
    public async Task StopKeepAliveAsync_DoesNotThrow_WhenNeverStarted()
    {
        var client = new StalkerClient(MakeFakeClient(), mac: "AA:BB:CC:DD:EE:FF");

        var act = async () => await client.StopKeepAliveAsync();

        await act.Should().NotThrowAsync();
    }

    // ------------------------------------------------------------------
    // StartKeepAliveAsync called twice — second call stops first loop
    // ------------------------------------------------------------------

    [Fact]
    public async Task StartKeepAliveAsync_Twice_DoesNotThrow()
    {
        var client = new StalkerClient(MakeFakeClient(), mac: "AA:BB:CC:DD:EE:FF");

        var act = async () =>
        {
            await client.StartKeepAliveAsync(interval: TimeSpan.FromSeconds(10));
            await client.StartKeepAliveAsync(interval: TimeSpan.FromSeconds(10));
            await client.StopKeepAliveAsync();
        };

        await act.Should().NotThrowAsync();
    }

    private sealed class StatusQueuedHandler : HttpMessageHandler
    {
        private readonly Queue<(string Json, HttpStatusCode Status)> _responses;

        public StatusQueuedHandler(Queue<(string, HttpStatusCode)> responses) => _responses = responses;

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var (json, status) = _responses.Count > 0
                ? _responses.Dequeue()
                : ("{}", HttpStatusCode.OK);
            return Task.FromResult(new HttpResponseMessage(status)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json"),
            });
        }
    }

    /// <summary>
    /// Returns a valid handshake token on the first request, then throws
    /// <see cref="HttpRequestException"/> on every subsequent request (simulating a
    /// transient network error during keep-alive pings). This exercises the
    /// <c>catch { /* Ignore ping failures */ }</c> branch inside the keep-alive loop.
    /// </summary>
    private sealed class ThrowingOnPingHandler : HttpMessageHandler
    {
        private int _callCount;
        private readonly Action _onCall;

        public ThrowingOnPingHandler(Action onCall) => _onCall = onCall;

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            _onCall();
            var count = System.Threading.Interlocked.Increment(ref _callCount);
            if (count == 1)
            {
                // First call = auto-handshake — return a token
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("""{"js":{"token":"tok"}}""", Encoding.UTF8, "application/json"),
                });
            }

            // Subsequent calls = keep-alive pings — throw to exercise the catch branch
            throw new HttpRequestException("Simulated network error");
        }
    }
}
