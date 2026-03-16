using System.Net;

using Crispy.Infrastructure.Jellyfin;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Jellyfin;

/// <summary>
/// Fake HTTP message handler driven by a delegate.
/// </summary>
internal sealed class FakeHttpHandler : HttpMessageHandler
{
    private readonly Func<HttpRequestMessage, HttpResponseMessage> _handler;

    public FakeHttpHandler(Func<HttpRequestMessage, HttpResponseMessage> handler)
        => _handler = handler;

    public FakeHttpHandler(HttpStatusCode statusCode)
        => _handler = _ => new HttpResponseMessage(statusCode);

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
        => Task.FromResult(_handler(request));
}

/// <summary>
/// Minimal IHttpClientFactory that always returns the same pre-built HttpClient.
/// </summary>
internal sealed class SingleClientFactory : IHttpClientFactory
{
    private readonly HttpClient _client;

    public SingleClientFactory(HttpClient client) => _client = client;

    public HttpClient CreateClient(string name) => _client;
}

[Trait("Category", "Unit")]
public sealed class JellyfinDiscoveryTests
{
    // ── helpers ─────────────────────────────────────────────────────────────

    private static IHttpClientFactory MakeFactory(HttpClient client) =>
        new SingleClientFactory(client);

    // ── ValidateServerAsync ──────────────────────────────────────────────────

    [Fact]
    public async Task ValidateServerAsync_ReturnsTrue_WhenServerResponds200()
    {
        // Arrange
        var handler = new FakeHttpHandler(HttpStatusCode.OK);
        var client = new HttpClient(handler);
        var factory = MakeFactory(client);
        var sut = new JellyfinDiscovery(factory, NullLogger<JellyfinDiscovery>.Instance);

        // Act
        var result = await sut.ValidateServerAsync("http://jellyfin.local:8096");

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task ValidateServerAsync_ReturnsFalse_WhenServerReturnsNon2xx()
    {
        // Arrange
        var handler = new FakeHttpHandler(HttpStatusCode.ServiceUnavailable);
        var client = new HttpClient(handler);
        var factory = MakeFactory(client);
        var sut = new JellyfinDiscovery(factory, NullLogger<JellyfinDiscovery>.Instance);

        // Act
        var result = await sut.ValidateServerAsync("http://jellyfin.local:8096");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task ValidateServerAsync_ReturnsFalse_WhenHttpThrows()
    {
        // Arrange
        var handler = new FakeHttpHandler(_ => throw new HttpRequestException("connection refused"));
        var client = new HttpClient(handler);
        var factory = MakeFactory(client);
        var sut = new JellyfinDiscovery(factory, NullLogger<JellyfinDiscovery>.Instance);

        // Act
        var result = await sut.ValidateServerAsync("http://unreachable.local");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task ValidateServerAsync_AppendsHealthPath_ToProvidedUrl()
    {
        // Arrange
        string? capturedUrl = null;
        var handler = new FakeHttpHandler(req =>
        {
            capturedUrl = req.RequestUri?.ToString();
            return new HttpResponseMessage(HttpStatusCode.OK);
        });
        var client = new HttpClient(handler);
        var factory = MakeFactory(client);
        var sut = new JellyfinDiscovery(factory, NullLogger<JellyfinDiscovery>.Instance);

        // Act
        await sut.ValidateServerAsync("http://jellyfin.local:8096/");

        // Assert
        capturedUrl.Should().Be("http://jellyfin.local:8096/health");
    }

    // ── JellyfinServerInfo ───────────────────────────────────────────────────

    [Fact]
    public void JellyfinServerInfo_PropertiesInitialiseCorrectly()
    {
        // Arrange / Act
        var info = new JellyfinServerInfo
        {
            Address = "http://server:8096",
            Id = "abc123",
            Name = "My Jellyfin",
            EndpointAddress = "192.168.1.10:8096",
        };

        // Assert
        info.Address.Should().Be("http://server:8096");
        info.Id.Should().Be("abc123");
        info.Name.Should().Be("My Jellyfin");
        info.EndpointAddress.Should().Be("192.168.1.10:8096");
    }

    [Fact]
    public void JellyfinServerInfo_DefaultValues_AreEmptyStrings()
    {
        var info = new JellyfinServerInfo();

        info.Address.Should().BeEmpty();
        info.Id.Should().BeEmpty();
        info.Name.Should().BeEmpty();
        info.EndpointAddress.Should().BeEmpty();
    }

    // ── DiscoverAsync ────────────────────────────────────────────────────────

    [Fact]
    public async Task DiscoverAsync_ReturnsEmptyList_WhenNoServersRespond()
    {
        // In a test environment, UDP broadcast to port 7359 receives no replies.
        // DiscoverAsync must not throw and must return an empty list.
        var handler = new FakeHttpHandler(HttpStatusCode.OK);
        var client = new HttpClient(handler);
        var factory = MakeFactory(client);
        var sut = new JellyfinDiscovery(factory, NullLogger<JellyfinDiscovery>.Instance);

        using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(100));
        var act = async () => await sut.DiscoverAsync(cts.Token);

        // Must not throw — even if OperationCanceledException is raised internally it is caught
        var result = await act.Should().NotThrowAsync();
        result.Subject.Should().NotBeNull();
    }

    [Fact]
    public async Task DiscoverAsync_ThrowsOperationCanceledException_WhenCancelledImmediately()
    {
        // DiscoverAsync propagates OperationCanceledException when the token is pre-cancelled
        // (the outer catch only swallows non-cancellation exceptions).
        var handler = new FakeHttpHandler(HttpStatusCode.OK);
        var client = new HttpClient(handler);
        var factory = MakeFactory(client);
        var sut = new JellyfinDiscovery(factory, NullLogger<JellyfinDiscovery>.Instance);

        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        var act = async () => await sut.DiscoverAsync(cts.Token);
        await act.Should().ThrowAsync<OperationCanceledException>();
    }
}
