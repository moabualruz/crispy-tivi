using System.Net;
using System.Text;
using System.Text.Json;

using Crispy.Infrastructure.Jellyfin;
using Crispy.Infrastructure.Security;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Jellyfin;

/// <summary>
/// Tests for JellyfinClient: Quick Connect flow, WebSocket reconnect logic, and item retrieval.
/// Uses a SequentialHttpMessageHandler to mock HTTP responses without NSubstitute.
/// </summary>
public class JellyfinClientTests
{
    // ─── Helper factory ───────────────────────────────────────────────────────

    private static JellyfinClient MakeClient(
        string? token,
        params (HttpStatusCode status, string json)[] responses)
    {
        var handler = new SequentialHttpMessageHandler(responses);
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://localhost:8096") };
        var encryption = new TestCredentialEncryption();
        return new JellyfinClient("http://localhost:8096", token, encryption, httpClient, NullLogger<JellyfinClient>.Instance);
    }

    // ─── Quick Connect ────────────────────────────────────────────────────────

    [Fact]
    public async Task InitiateQuickConnectAsync_ReturnsSecretAndCode()
    {
        var client = MakeClient(null,
            (HttpStatusCode.OK, """{"Secret":"abc123","Code":"123456"}"""));

        var (secret, code) = await client.InitiateQuickConnectAsync(CancellationToken.None);

        secret.Should().Be("abc123");
        code.Should().Be("123456");
    }

    [Fact]
    public async Task PollQuickConnectAsync_ReturnsFalse_OnFirstPoll_ThenTrue_OnSecond()
    {
        var client = MakeClient(null,
            (HttpStatusCode.OK, """{"Authenticated":false}"""),
            (HttpStatusCode.OK, """{"Authenticated":true}"""));

        // pollIntervalMs=1 so the test doesn't wait 1 second
        var result = await client.PollQuickConnectAsync("abc123", pollIntervalMs: 1, CancellationToken.None);

        result.Should().BeTrue();
    }

    [Fact]
    public async Task AuthenticateWithQuickConnectAsync_SetsAccessToken_AndEncryptsIt()
    {
        var enc = new TestCredentialEncryption();
        var handler = new SequentialHttpMessageHandler(
            (HttpStatusCode.OK, """{"AccessToken":"tok123","UserId":"user1"}"""));
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri("http://localhost:8096") };
        var client = new JellyfinClient("http://localhost:8096", null, enc, httpClient, NullLogger<JellyfinClient>.Instance);

        await client.AuthenticateWithQuickConnectAsync("abc123", CancellationToken.None);

        client.AccessToken.Should().Be("tok123");
        enc.LastEncrypted.Should().Be("tok123");
    }

    // ─── Standard auth ────────────────────────────────────────────────────────

    [Fact]
    public async Task AuthenticateAsync_SetsAccessToken()
    {
        var client = MakeClient(null,
            (HttpStatusCode.OK, """{"AccessToken":"tok_user","UserId":"user1"}"""));

        await client.AuthenticateAsync("admin", "password", CancellationToken.None);

        client.AccessToken.Should().Be("tok_user");
    }

    // ─── WebSocket reconnect ───────────────────────────────────────────────────

    [Fact]
    public async Task SimulateWebSocketReconnect_ReturnsReconnectCount_WhenAborted()
    {
        // Real WebSocket cannot be opened in unit tests — the SimulateWebSocketReconnectAsync
        // method verifies that the reconnect logic would trigger given abortedCount >= 1.
        var client = MakeClient("tok");

        var reconnectCount = await client.SimulateWebSocketReconnectAsync(
            abortedCount: 1, maxReconnects: 1, CancellationToken.None);

        reconnectCount.Should().BeGreaterThanOrEqualTo(1,
            "a WebSocket in Aborted state should trigger at least one reconnect attempt");
    }

    [Fact]
    public async Task SimulateWebSocketReconnect_ReturnsZero_WhenNotAborted()
    {
        var client = MakeClient("tok");

        var reconnectCount = await client.SimulateWebSocketReconnectAsync(
            abortedCount: 0, maxReconnects: 1, CancellationToken.None);

        reconnectCount.Should().Be(0);
    }

    // ─── GetItemsAsync ─────────────────────────────────────────────────────────

    [Fact]
    public async Task GetItemsAsync_MapsTwoItemsFromResponse()
    {
        const string json = """
        {
            "Items": [
                {"Id":"id1","Name":"Movie One","Type":"Movie","ProductionYear":2020},
                {"Id":"id2","Name":"Movie Two","Type":"Movie","ProductionYear":2021}
            ],
            "TotalRecordCount": 2
        }
        """;
        var client = MakeClient("tok", (HttpStatusCode.OK, json));

        var items = await client.GetItemsAsync("lib1", "Movie", 0, 100, CancellationToken.None);

        items.Should().HaveCount(2);
        items[0].Name.Should().Be("Movie One");
        items[1].Name.Should().Be("Movie Two");
    }

    [Fact]
    public async Task GetItemsAsync_ReturnsEmpty_WhenNoItems()
    {
        const string json = """{"Items":[],"TotalRecordCount":0}""";
        var client = MakeClient("tok", (HttpStatusCode.OK, json));

        var items = await client.GetItemsAsync("lib1", "Movie", 0, 100, CancellationToken.None);

        items.Should().BeEmpty();
    }
}

// ─── Test doubles ─────────────────────────────────────────────────────────────

/// <summary>Sequential HTTP handler — dequeues pre-configured responses in order.</summary>
internal sealed class SequentialHttpMessageHandler : HttpMessageHandler
{
    private readonly Queue<(HttpStatusCode Status, string Json)> _responses;

    public SequentialHttpMessageHandler(params (HttpStatusCode Status, string Json)[] responses)
    {
        _responses = new Queue<(HttpStatusCode, string)>(responses);
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var (status, json) = _responses.Count > 0
            ? _responses.Dequeue()
            : (HttpStatusCode.OK, "{}");

        var response = new HttpResponseMessage(status)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json"),
        };
        return Task.FromResult(response);
    }
}

/// <summary>Simple test double for ICredentialEncryption that records what was encrypted.</summary>
internal sealed class TestCredentialEncryption : Crispy.Application.Security.ICredentialEncryption
{
    public string? LastEncrypted { get; private set; }

    public string Encrypt(string plaintext)
    {
        LastEncrypted = plaintext;
        return "encrypted_" + plaintext;
    }

    public string Decrypt(string ciphertext) => ciphertext.Replace("encrypted_", string.Empty);
}
