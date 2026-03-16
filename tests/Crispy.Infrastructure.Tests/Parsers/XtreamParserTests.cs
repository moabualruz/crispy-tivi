using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Parsers.M3U;
using Crispy.Infrastructure.Parsers.Xtream;
using Crispy.Infrastructure.Tests.TestData;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

[Trait("Category", "Unit")]
public class XtreamParserTests
{
    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static XtreamParser MakeParser(FakeHttpHandler handler)
    {
        var httpClient = new HttpClient(handler)
        {
            BaseAddress = new Uri("http://fake-xtream.test"),
        };
        var xtreamClient = new XtreamClient(httpClient);
        var m3uParser = new M3UParser();
        return new XtreamParser(xtreamClient, m3uParser, NullLogger<XtreamParser>.Instance);
    }

    // ─── Successful auth + parse ──────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_SuccessfulAuth_PopulatesChannelsMoviesSeries()
    {
        var authJson = TestSourceProvider.LoadText("xtream-auth.json");
        var liveJson = TestSourceProvider.LoadText("xtream-live.json");
        var vodJson = TestSourceProvider.LoadText("xtream-vod.json");
        var seriesJson = TestSourceProvider.LoadText("xtream-series.json");

        // Action-specific routes must be registered before the bare auth route because
        // FakeHttpHandler uses first-match wins and all URLs contain "player_api.php".
        var handler = new FakeHttpHandler()
            .WithResponse("get_live_streams", liveJson)
            .WithResponse("get_vod_streams", vodJson)
            .WithResponse("get_series", seriesJson)
            .WithResponse("player_api.php", authJson);

        var parser = MakeParser(handler);
        var source = TestSourceProvider.XtreamSource();

        var result = await parser.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
        result.Channels.Should().HaveCount(3);
        result.Movies.Should().HaveCount(2);
        result.Series.Should().HaveCount(1);
    }

    [Fact]
    public async Task ParseAsync_SuccessfulAuth_ChannelTitlesMatchJson()
    {
        var handler = new FakeHttpHandler()
            .WithResponse("get_live_streams", TestSourceProvider.LoadText("xtream-live.json"))
            .WithResponse("get_vod_streams", "[]")
            .WithResponse("get_series", "[]")
            .WithResponse("player_api.php", TestSourceProvider.LoadText("xtream-auth.json"));

        var result = await MakeParser(handler).ParseAsync(TestSourceProvider.XtreamSource());

        result.Channels.Select(c => c.Title)
            .Should().ContainInOrder("BBC One", "CNN", "ESPN");
    }

    [Fact]
    public async Task ParseAsync_SuccessfulAuth_ChannelEpgIdsSet()
    {
        var handler = new FakeHttpHandler()
            .WithResponse("get_live_streams", TestSourceProvider.LoadText("xtream-live.json"))
            .WithResponse("get_vod_streams", "[]")
            .WithResponse("get_series", "[]")
            .WithResponse("player_api.php", TestSourceProvider.LoadText("xtream-auth.json"));

        var result = await MakeParser(handler).ParseAsync(TestSourceProvider.XtreamSource());

        result.Channels[0].TvgId.Should().Be("bbc1.uk");
        result.Channels[1].TvgId.Should().Be("cnn.us");
    }

    [Fact]
    public async Task ParseAsync_SuccessfulAuth_MovieTitlesMatchJson()
    {
        var handler = new FakeHttpHandler()
            .WithResponse("get_live_streams", "[]")
            .WithResponse("get_vod_streams", TestSourceProvider.LoadText("xtream-vod.json"))
            .WithResponse("get_series", "[]")
            .WithResponse("player_api.php", TestSourceProvider.LoadText("xtream-auth.json"));

        var result = await MakeParser(handler).ParseAsync(TestSourceProvider.XtreamSource());

        result.Movies.Select(m => m.Title)
            .Should().ContainInOrder("Inception", "The Matrix");
    }

    [Fact]
    public async Task ParseAsync_SuccessfulAuth_SeriesTitleMatchJson()
    {
        var handler = new FakeHttpHandler()
            .WithResponse("get_live_streams", "[]")
            .WithResponse("get_vod_streams", "[]")
            .WithResponse("get_series", TestSourceProvider.LoadText("xtream-series.json"))
            .WithResponse("player_api.php", TestSourceProvider.LoadText("xtream-auth.json"));

        var result = await MakeParser(handler).ParseAsync(TestSourceProvider.XtreamSource());

        result.Series[0].Title.Should().Be("Breaking Bad");
    }

    // ─── Empty live streams ───────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_EmptyLiveStreams_ReturnsEmptyChannels()
    {
        var handler = new FakeHttpHandler()
            .WithResponse("get_live_streams", "[]")
            .WithResponse("get_vod_streams", "[]")
            .WithResponse("get_series", "[]")
            .WithResponse("player_api.php", TestSourceProvider.LoadText("xtream-auth.json"));

        var result = await MakeParser(handler).ParseAsync(TestSourceProvider.XtreamSource());

        result.IsSuccess.Should().BeTrue();
        result.Channels.Should().BeEmpty();
    }

    // ─── Auth failure / fallback ──────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_AuthFailure_FallsBackAndReturnsResult()
    {
        // FakeHttpHandler returns 401 for player_api.php → XtreamClient throws HttpRequestException
        // XtreamParser catches it and falls back to M3U URL via a new HttpClient()
        // Since the fallback URL (http://fake-xtream.test/get.php?...) is not reachable,
        // the fallback itself will throw and the parser returns a ParseResult with an Error.
        var handler = new FakeHttpHandler()
            .WithResponse("player_api.php", "{}", System.Net.HttpStatusCode.Unauthorized);

        var result = await MakeParser(handler).ParseAsync(TestSourceProvider.XtreamSource());

        // Either error set (fallback also failed) or channels empty — either is acceptable
        // behaviour when auth fails; what matters is no exception escaped.
        result.Should().NotBeNull();
        (result.Error is not null || result.Channels.Count == 0).Should().BeTrue();
    }

    // ─── Missing credentials ──────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_MissingCredentials_UsesEmptyStrings_DoesNotThrow()
    {
        // Source with null username/password — parser should substitute empty strings
        // and attempt auth (which will fail), then fall back gracefully.
        var handler = new FakeHttpHandler()
            .WithResponse("player_api.php", "{}", System.Net.HttpStatusCode.Unauthorized);

        var result = await MakeParser(handler).ParseAsync(TestSourceProvider.XtreamSourceNoCredentials());

        result.Should().NotBeNull();
    }

    // ─── Cancellation ─────────────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_CancelledToken_ThrowsOrReturnsBeforeCompletion()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        var handler = new FakeHttpHandler()
            .WithResponse("player_api.php", TestSourceProvider.LoadText("xtream-auth.json"));

        var parser = MakeParser(handler);
        var source = TestSourceProvider.XtreamSource();

        var act = async () => await parser.ParseAsync(source, cts.Token);

        // May throw OperationCanceledException or TaskCanceledException (both acceptable)
        await act.Should().ThrowAsync<OperationCanceledException>();
    }
}
