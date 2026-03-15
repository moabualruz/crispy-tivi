using System.Net;
using System.Text;

using Crispy.Infrastructure.Parsers.Stalker;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

public class StalkerClientTests
{
    private static HttpClient MakeFakeClient(string defaultResponse = "{}")
    {
        return new HttpClient(new FakeMessageHandler(defaultResponse))
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

        public FakeMessageHandler(string response) => _response = response;

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
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
