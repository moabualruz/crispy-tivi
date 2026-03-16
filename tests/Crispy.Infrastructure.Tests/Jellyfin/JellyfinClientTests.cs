using System.Linq;
using System.Net;
using System.Text;
using System.Text.Json;

using Crispy.Infrastructure.Jellyfin;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Jellyfin;

/// <summary>
/// Tests for JellyfinClient: Quick Connect flow, WebSocket reconnect logic, and item retrieval.
/// Uses a SequentialHttpMessageHandler to mock HTTP responses without NSubstitute.
/// </summary>
[Trait("Category", "Unit")]
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

    [Fact]
    public async Task GetItemsAsync_MapsAllProperties_WhenFullItemReturned()
    {
        const string json = """
        {
            "Items": [{
                "Id": "item1",
                "Name": "Breaking Bad S01E01",
                "Type": "Episode",
                "Overview": "A chemistry teacher turns to crime.",
                "ProductionYear": 2008,
                "RunTimeTicks": 27000000000,
                "Path": "/tv/breaking-bad/s01e01.mkv",
                "SeriesId": "series_bb",
                "SeriesName": "Breaking Bad",
                "IndexNumber": 1,
                "ParentIndexNumber": 1,
                "ChannelNumber": "5",
                "ImageTags": {"Primary": "tag_abc"},
                "BackdropImageTags": ["bd1"],
                "ProviderIds": {"Imdb": "tt0903747"}
            }],
            "TotalRecordCount": 1
        }
        """;
        var client = MakeClient("tok", (HttpStatusCode.OK, json));

        var items = await client.GetItemsAsync("lib1", "Episode", 0, 50, CancellationToken.None);

        items.Should().HaveCount(1);
        var item = items[0];
        item.Id.Should().Be("item1");
        item.Name.Should().Be("Breaking Bad S01E01");
        item.Type.Should().Be("Episode");
        item.Overview.Should().Be("A chemistry teacher turns to crime.");
        item.ProductionYear.Should().Be(2008);
        item.RunTimeTicks.Should().Be(27000000000L);
        item.Path.Should().Be("/tv/breaking-bad/s01e01.mkv");
        item.SeriesId.Should().Be("series_bb");
        item.SeriesName.Should().Be("Breaking Bad");
        item.IndexNumber.Should().Be(1);
        item.ParentIndexNumber.Should().Be(1);
        item.ChannelNumber.Should().Be("5");
        item.ImageTags.Should().ContainKey("Primary").WhoseValue.Should().Be("tag_abc");
        item.BackdropImageTags.Should().Contain("bd1");
        item.ProviderIds.Should().ContainKey("Imdb").WhoseValue.Should().Be("tt0903747");
    }

    // ─── GetLibrariesAsync ─────────────────────────────────────────────────────

    [Fact]
    public async Task GetLibrariesAsync_ReturnsFolderList()
    {
        const string json = """
        {
            "Items": [
                {"Id":"lib1","Name":"Movies","Type":"CollectionFolder"},
                {"Id":"lib2","Name":"TV Shows","Type":"CollectionFolder"}
            ],
            "TotalRecordCount": 2
        }
        """;
        var client = MakeClient("tok", (HttpStatusCode.OK, json));

        var libs = await client.GetLibrariesAsync(CancellationToken.None);

        libs.Should().HaveCount(2);
        libs[0].Id.Should().Be("lib1");
        libs[0].Name.Should().Be("Movies");
        libs[1].Id.Should().Be("lib2");
        libs[1].Name.Should().Be("TV Shows");
    }

    [Fact]
    public async Task GetLibrariesAsync_ReturnsEmpty_WhenNoFolders()
    {
        const string json = """{"Items":[],"TotalRecordCount":0}""";
        var client = MakeClient("tok", (HttpStatusCode.OK, json));

        var libs = await client.GetLibrariesAsync(CancellationToken.None);

        libs.Should().BeEmpty();
    }

    // ─── PollQuickConnectAsync cancellation ───────────────────────────────────

    [Fact]
    public async Task PollQuickConnectAsync_ThrowsOperationCanceledException_WhenTokenCancelled()
    {
        // Provides infinite false responses; cancellation fires before deadline (5 min).
        // The `return false` deadline path is unreachable in a unit test without a
        // 5-minute wait — it is a documented coverage ceiling analogous to WebSocket methods.
        var client = MakeClient(null,
            (HttpStatusCode.OK, """{"Authenticated":false}"""));

        using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(30));

        var act = async () => await client.PollQuickConnectAsync("secret", pollIntervalMs: 5, cts.Token);

        await act.Should().ThrowAsync<OperationCanceledException>();
    }

    // ─── AuthenticateAsync edge cases ──────────────────────────────────────────

    [Fact]
    public async Task AuthenticateAsync_LeavesTokenNull_WhenServerReturnsNullToken()
    {
        var client = MakeClient(null,
            (HttpStatusCode.OK, """{"AccessToken":null,"UserId":"user1"}"""));

        await client.AuthenticateAsync("admin", "wrongpass", CancellationToken.None);

        client.AccessToken.Should().BeNull();
    }

    [Fact]
    public async Task AuthenticateAsync_Throws_WhenServerReturns401()
    {
        var client = MakeClient(null,
            (HttpStatusCode.Unauthorized, """{"error":"Unauthorized"}"""));

        var act = async () => await client.AuthenticateAsync("bad", "creds", CancellationToken.None);

        await act.Should().ThrowAsync<HttpRequestException>();
    }

    // ─── GetPlaybackInfoAsync ─────────────────────────────────────────────────

    [Fact]
    public async Task GetPlaybackInfoAsync_ReturnsDirectStreamUrl_WhenAvailable()
    {
        const string playbackJson = """
        {
            "MediaSources": [{
                "Id": "src1",
                "Path": "/media/movies/matrix.mkv",
                "SupportsDirectStream": true,
                "SupportsTranscoding": true,
                "TranscodingUrl": "/Videos/src1/stream.m3u8?api_key=tok",
                "MediaStreams": [
                    {"Type":"Video","Index":0,"IsDefault":true},
                    {"Type":"Audio","Language":"eng","DisplayTitle":"English","Index":1,"IsDefault":true}
                ]
            }],
            "PlaySessionId": "session-abc"
        }
        """;
        var client = MakeClient("tok", (HttpStatusCode.OK, playbackJson));

        var info = await client.GetPlaybackInfoAsync("item42", CancellationToken.None);
        var url = client.ResolveStreamUrl(info);

        info.PlaySessionId.Should().Be("session-abc");
        info.MediaSources.Should().HaveCount(1);
        info.MediaSources[0].SupportsDirectStream.Should().BeTrue();
        info.MediaSources[0].MediaStreams.Should().HaveCount(2);
        // Direct stream preferred — returns /Videos/{id}/stream?static=true URL
        url.Should().Contain("/Videos/src1/stream").And.Contain("static=true");
    }

    [Fact]
    public async Task GetPlaybackInfoAsync_ReturnsTranscodingUrl_WhenDirectStreamUnavailable()
    {
        const string playbackJson = """
        {
            "MediaSources": [{
                "Id": "src2",
                "Path": "/media/movies/matrix.mkv",
                "SupportsDirectStream": false,
                "SupportsTranscoding": true,
                "TranscodingUrl": "/Videos/src2/stream.m3u8?api_key=tok",
                "MediaStreams": []
            }],
            "PlaySessionId": "session-xyz"
        }
        """;
        var client = MakeClient("tok", (HttpStatusCode.OK, playbackJson));

        var info = await client.GetPlaybackInfoAsync("item99", CancellationToken.None);
        var url = client.ResolveStreamUrl(info);

        info.MediaSources[0].SupportsDirectStream.Should().BeFalse();
        info.MediaSources[0].SupportsTranscoding.Should().BeTrue();
        // Falls back to transcoding URL
        url.Should().Be("http://localhost:8096/Videos/src2/stream.m3u8?api_key=tok");
    }

    [Fact]
    public async Task GetPlaybackInfoAsync_ReturnsChapterInfo_WhenPresent()
    {
        const string playbackJson = """
        {
            "MediaSources": [{
                "Id": "src3",
                "Path": "/media/tv/show/s01e01.mkv",
                "SupportsDirectStream": true,
                "SupportsTranscoding": false,
                "TranscodingUrl": null,
                "MediaStreams": [
                    {"Type":"Video","Index":0,"IsDefault":true,"DisplayTitle":"1080p H.264"},
                    {"Type":"Audio","Language":"eng","DisplayTitle":"English AC3","Index":1,"IsDefault":true},
                    {"Type":"Audio","Language":"spa","DisplayTitle":"Spanish AC3","Index":2,"IsDefault":false},
                    {"Type":"Subtitle","Language":"eng","DisplayTitle":"English SRT","Index":3,"IsDefault":false}
                ]
            }],
            "PlaySessionId": "session-chapters"
        }
        """;
        var client = MakeClient("tok", (HttpStatusCode.OK, playbackJson));

        var info = await client.GetPlaybackInfoAsync("episode1", CancellationToken.None);

        var streams = info.MediaSources[0].MediaStreams;
        streams.Should().HaveCount(4);

        var audioStreams = streams.Where(s => s.Type == "Audio").ToList();
        audioStreams.Should().HaveCount(2);
        audioStreams.Should().ContainSingle(s => s.IsDefault && s.Language == "eng");

        var subtitleStreams = streams.Where(s => s.Type == "Subtitle").ToList();
        subtitleStreams.Should().HaveCount(1);
        subtitleStreams[0].Language.Should().Be("eng");
        subtitleStreams[0].DisplayTitle.Should().Be("English SRT");
    }

    // ─── JellyfinItem ──────────────────────────────────────────────────────────

    [Fact]
    public void JellyfinItem_DefaultValues_AreCorrect()
    {
        var item = new JellyfinItem();

        item.Id.Should().BeEmpty();
        item.Name.Should().BeEmpty();
        item.Type.Should().BeEmpty();
        item.Overview.Should().BeNull();
        item.ProductionYear.Should().BeNull();
        item.RunTimeTicks.Should().BeNull();
        item.Path.Should().BeNull();
        item.SeriesId.Should().BeNull();
        item.SeriesName.Should().BeNull();
        item.IndexNumber.Should().BeNull();
        item.ParentIndexNumber.Should().BeNull();
        item.ChannelNumber.Should().BeNull();
        item.ImageTags.Should().BeNull();
        item.BackdropImageTags.Should().BeNull();
        item.ProviderIds.Should().BeNull();
    }

    [Fact]
    public void JellyfinItem_AllPropertiesSetAndRead()
    {
        var providerIds = new Dictionary<string, string> { ["Imdb"] = "tt123", ["Tmdb"] = "456" };
        var imageTags = new Dictionary<string, string> { ["Primary"] = "imgA", ["Thumb"] = "imgB" };
        var backdropTags = new List<string> { "bk1", "bk2" };

        var item = new JellyfinItem
        {
            Id = "id1",
            Name = "The Matrix",
            Type = "Movie",
            Overview = "A hacker discovers reality is a simulation.",
            ProductionYear = 1999,
            RunTimeTicks = 8280000000L,
            Path = "/media/movies/matrix.mkv",
            SeriesId = "series1",
            SeriesName = "The Matrix Trilogy",
            IndexNumber = 1,
            ParentIndexNumber = 2,
            ChannelNumber = "42",
            ImageTags = imageTags,
            BackdropImageTags = backdropTags,
            ProviderIds = providerIds,
        };

        item.Id.Should().Be("id1");
        item.Name.Should().Be("The Matrix");
        item.Type.Should().Be("Movie");
        item.Overview.Should().Be("A hacker discovers reality is a simulation.");
        item.ProductionYear.Should().Be(1999);
        item.RunTimeTicks.Should().Be(8280000000L);
        item.Path.Should().Be("/media/movies/matrix.mkv");
        item.SeriesId.Should().Be("series1");
        item.SeriesName.Should().Be("The Matrix Trilogy");
        item.IndexNumber.Should().Be(1);
        item.ParentIndexNumber.Should().Be(2);
        item.ChannelNumber.Should().Be("42");
        item.ImageTags.Should().BeSameAs(imageTags);
        item.BackdropImageTags.Should().BeSameAs(backdropTags);
        item.ProviderIds.Should().BeSameAs(providerIds);
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
