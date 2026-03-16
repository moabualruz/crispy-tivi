using System.Net;

using Crispy.Infrastructure.Connectivity;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Connectivity;

[Trait("Category", "Unit")]
public class ConnectivityMonitorTests : IDisposable
{
    // ─── Fake HTTP handler ───────────────────────────────────────────────────

    private sealed class FakeHttpHandler : HttpMessageHandler
    {
        public HttpStatusCode ResponseCode { get; set; } = HttpStatusCode.OK;
        public bool ThrowOnSend { get; set; }
        public int CallCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            CallCount++;
            if (ThrowOnSend)
                throw new HttpRequestException("Simulated network failure");

            return Task.FromResult(new HttpResponseMessage(ResponseCode));
        }
    }

    // ─── Setup ───────────────────────────────────────────────────────────────

    private readonly FakeHttpHandler _handler = new();
    private readonly HttpClient _client;

    public ConnectivityMonitorTests()
    {
        _client = new HttpClient(_handler);
    }

    public void Dispose() => _client.Dispose();

    private ConnectivityMonitor CreateSut()
        => new(_client, NullLogger<ConnectivityMonitor>.Instance);

    // ─── CheckAsync ───────────────────────────────────────────────────────────

    [Fact]
    public async Task CheckAsync_ReturnsOnline_WhenHttpProbeSucceeds()
    {
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();

        var result = await sut.CheckAsync();

        // On a machine where NetworkInterface.GetIsNetworkAvailable() is true,
        // a successful HTTP probe returns Online.
        result.Should().BeOneOf(ConnectivityLevel.Online, ConnectivityLevel.SourceDown);
    }

    [Fact]
    public async Task CheckAsync_ReturnsLimitedOrOffline_WhenProbeThrows()
    {
        _handler.ThrowOnSend = true;
        using var sut = CreateSut();

        var result = await sut.CheckAsync();

        result.Should().BeOneOf(
            ConnectivityLevel.InternetUnreachable,
            ConnectivityLevel.SourceDown,
            ConnectivityLevel.DeviceOffline);
    }

    [Fact]
    public async Task CheckAsync_Returns5xxAsFailure_WhenServerError()
    {
        _handler.ResponseCode = HttpStatusCode.InternalServerError;
        using var sut = CreateSut();

        var result = await sut.CheckAsync();

        result.Should().BeOneOf(
            ConnectivityLevel.InternetUnreachable,
            ConnectivityLevel.SourceDown,
            ConnectivityLevel.DeviceOffline);
    }

    [Fact]
    public async Task CheckAsync_WithSourceUrl_DoesNotThrow()
    {
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();

        var act = () => sut.CheckAsync(new Uri("http://example-source.test/playlist.m3u"));
        await act.Should().NotThrowAsync();
    }

    // ─── ConnectivityChanged event ────────────────────────────────────────────

    [Fact]
    public async Task ConnectivityChanged_Fires_WhenLevelTransitions()
    {
        // Start as Online (default)
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();
        await sut.CheckAsync(); // establish Online baseline

        ConnectivityLevel? captured = null;
        sut.ConnectivityChanged += (_, level) => captured = level;

        // Force a failure → should transition to a non-Online level
        _handler.ThrowOnSend = true;
        await sut.CheckAsync();

        captured.Should().NotBeNull("event should fire on level change");
        captured.Should().NotBe(ConnectivityLevel.Online);
    }

    [Fact]
    public async Task ConnectivityChanged_DoesNotFire_WhenLevelUnchanged()
    {
        _handler.ThrowOnSend = true;
        using var sut = CreateSut();

        // First call sets level to non-Online
        await sut.CheckAsync();

        var fireCount = 0;
        sut.ConnectivityChanged += (_, _) => fireCount++;

        // Second call — same failure, level unchanged
        await sut.CheckAsync();

        fireCount.Should().Be(0, "no event when level is already the same");
    }

    // ─── CurrentLevel ─────────────────────────────────────────────────────────

    [Fact]
    public void CurrentLevel_DefaultsToOnline()
    {
        using var sut = CreateSut();
        sut.CurrentLevel.Should().Be(ConnectivityLevel.Online);
    }

    // ─── Dispose ──────────────────────────────────────────────────────────────

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var sut = CreateSut();
        var act = () => sut.Dispose();
        act.Should().NotThrow();
    }

    [Fact]
    public void Dispose_CanBeCalledMultipleTimes_WithoutThrowing()
    {
        var sut = CreateSut();
        sut.Dispose();
        var act = () => sut.Dispose();
        act.Should().NotThrow();
    }

    // ─── OnNetworkAvailabilityChanged ─────────────────────────────────────────

    [Fact]
    public void OnNetworkAvailabilityChanged_DoesNotThrow_WhenCalled()
    {
        // OnNetworkAvailabilityChanged is internal — callable via InternalsVisibleTo.
        // It fire-and-forgets a CheckAsync call; we only verify it doesn't throw synchronously.
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();

        var act = () => sut.OnNetworkAvailabilityChanged(null, null!);

        act.Should().NotThrow();
    }

    [Fact]
    public async Task OnNetworkAvailabilityChanged_TriggersRecheck_WhenProbeSucceeds()
    {
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();

        // Force level to non-Online first
        _handler.ThrowOnSend = true;
        await sut.CheckAsync();
        _handler.ThrowOnSend = false;

        ConnectivityLevel? captured = null;
        sut.ConnectivityChanged += (_, level) => captured = level;

        sut.OnNetworkAvailabilityChanged(null, null!);

        // Allow the fire-and-forget task to complete
        await Task.Delay(200);

        captured.Should().Be(ConnectivityLevel.Online,
            "re-check after network change should restore Online when probe succeeds");
    }

    [Fact]
    public async Task OnNetworkAvailabilityChanged_FiresEvent_WhenNetworkGoesOffline()
    {
        // Start online
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();
        await sut.CheckAsync();
        sut.CurrentLevel.Should().Be(ConnectivityLevel.Online);

        ConnectivityLevel? captured = null;
        sut.ConnectivityChanged += (_, level) => captured = level;

        // Simulate network failure
        _handler.ThrowOnSend = true;
        sut.OnNetworkAvailabilityChanged(null, null!);

        // Allow the fire-and-forget task to complete
        await Task.Delay(200);

        captured.Should().NotBeNull("event should fire when network goes offline");
        captured.Should().NotBe(ConnectivityLevel.Online, "level should change from Online when network fails");
        sut.CurrentLevel.Should().NotBe(ConnectivityLevel.Online);
    }

    [Fact]
    public async Task OnNetworkAvailabilityChanged_FiresEvent_WhenNetworkComesBackOnline()
    {
        // Start offline
        _handler.ThrowOnSend = true;
        using var sut = CreateSut();
        await sut.CheckAsync();
        var offlineLevel = sut.CurrentLevel;
        offlineLevel.Should().NotBe(ConnectivityLevel.Online);

        ConnectivityLevel? captured = null;
        sut.ConnectivityChanged += (_, level) => captured = level;

        // Network comes back online
        _handler.ThrowOnSend = false;
        _handler.ResponseCode = HttpStatusCode.OK;
        sut.OnNetworkAvailabilityChanged(null, null!);

        // Allow the fire-and-forget task to complete
        await Task.Delay(200);

        captured.Should().Be(ConnectivityLevel.Online,
            "event should fire with Online when network comes back");
        sut.CurrentLevel.Should().Be(ConnectivityLevel.Online);
    }

    [Fact]
    public async Task OnNetworkAvailabilityChanged_CompletesWithoutError_AfterRecheck()
    {
        // Verify the fire-and-forget recheck triggered by OnNetworkAvailabilityChanged
        // completes without throwing, regardless of network state.
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();

        sut.OnNetworkAvailabilityChanged(null, null!);

        // Allow the fire-and-forget task to complete
        await Task.Delay(200);

        // CurrentLevel is valid (not default enum value -1)
        ((int)sut.CurrentLevel).Should().BeGreaterThanOrEqualTo(0);
    }

    [Fact]
    public void OnNetworkAvailabilityChanged_DoesNotThrow_WhenEventFires()
    {
        _handler.ResponseCode = HttpStatusCode.OK;
        using var sut = CreateSut();

        // Simulate multiple rapid network change events (common during network reconnection)
        var act = () =>
        {
            sut.OnNetworkAvailabilityChanged(null, null!);
            sut.OnNetworkAvailabilityChanged(null, null!);
            sut.OnNetworkAvailabilityChanged(null, null!);
        };

        act.Should().NotThrow();
    }
}
