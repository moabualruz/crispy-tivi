using System.Net;
using System.Text;

using Crispy.Application.Sources;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Jellyfin;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Jellyfin;

[Trait("Category", "Unit")]
public class JellyfinSyncServiceTests
{
    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static Source MakeSource(
        string? username = null,
        string? password = null,
        string? accessToken = null) => new()
        {
            Name = "Jellyfin Test",
            Url = "http://jellyfin.local:8096",
            SourceType = SourceType.Jellyfin,
            ProfileId = 1,
            Username = username,
            Password = password,
        };

    /// <summary>
    /// Builds a JellyfinSyncService whose inner JellyfinClient responds
    /// with the provided sequential HTTP responses.
    /// </summary>
    private static JellyfinSyncService MakeSut(
        Source source,
        string? presetToken,
        params (HttpStatusCode status, string json)[] responses)
    {
        var handler = new SequentialHttpMessageHandler(responses);
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri(source.Url) };
        var enc = new TestCredentialEncryption();

        JellyfinClient ClientFactory(Source s)
            => new(s.Url, presetToken, enc, httpClient, NullLogger<JellyfinClient>.Instance);

        return new JellyfinSyncService(ClientFactory, NullLogger<JellyfinSyncService>.Instance);
    }

    // ─── No credentials ───────────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_ReturnsError_WhenNoCredentialsAndNoToken()
    {
        var source = MakeSource();
        var sut = MakeSut(source, presetToken: null);

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("No credentials");
    }

    // ─── With access token (no re-auth needed) ────────────────────────────────

    [Fact]
    public async Task ParseAsync_ReturnsEmptyCollections_WhenNoLibraries()
    {
        var source = MakeSource();
        const string emptyLibraries = """{"Items":[],"TotalRecordCount":0}""";
        var sut = MakeSut(source, presetToken: "tok123", (HttpStatusCode.OK, emptyLibraries));

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
        result.Channels.Should().BeEmpty();
        result.Movies.Should().BeEmpty();
        result.Series.Should().BeEmpty();
    }

    [Fact]
    public async Task ParseAsync_MapsMovieLibrary_WhenCollectionTypeIsMovies()
    {
        var source = MakeSource();
        // /Library/VirtualFolders returns items where Type = collection type (e.g. "movies")
        const string libraries = """
        {"Items":[{"Id":"lib1","Name":"Movies","Type":"movies"}],"TotalRecordCount":1}
        """;
        const string movieItems = """
        {"Items":[
            {"Id":"m1","Name":"Inception","Type":"Movie","ProductionYear":2010,
             "Overview":"A thief enters dreams.","RunTimeTicks":84600000000,
             "ProviderIds":{"Tmdb":"27205"},"ImageTags":{"Primary":"tag1"}}
        ],"TotalRecordCount":1}
        """;
        var sut = MakeSut(source, presetToken: "tok",
            (HttpStatusCode.OK, libraries),
            (HttpStatusCode.OK, movieItems));

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
        result.Movies.Should().HaveCount(1);
        var movie = result.Movies[0];
        movie.Title.Should().Be("Inception");
        movie.Overview.Should().Be("A thief enters dreams.");
        movie.TmdbId.Should().Be(27205);
        movie.RuntimeMinutes.Should().Be(141); // 84600000000 / 600_000_000
        movie.Thumbnail.Should().Contain("m1");
        movie.SourceId.Should().Be(source.Id);
    }

    [Fact]
    public async Task ParseAsync_MapsSeriesAndEpisodesLibrary_WhenCollectionTypeIsTvShows()
    {
        var source = MakeSource();
        const string libraries = """
        {"Items":[{"Id":"lib2","Name":"TV","Type":"tvshows"}],"TotalRecordCount":1}
        """;
        const string seriesItems = """
        {"Items":[{"Id":"s1","Name":"Breaking Bad","Type":"Series","ProviderIds":{"Tmdb":"1396"}}],"TotalRecordCount":1}
        """;
        const string episodeItems = """
        {"Items":[{"Id":"e1","Name":"Pilot","Type":"Episode","ParentIndexNumber":1,"IndexNumber":1}],"TotalRecordCount":1}
        """;
        var sut = MakeSut(source, presetToken: "tok",
            (HttpStatusCode.OK, libraries),
            (HttpStatusCode.OK, seriesItems),
            (HttpStatusCode.OK, episodeItems));

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
        result.Series.Should().HaveCount(1);
        result.Series[0].Title.Should().Be("Breaking Bad");
        result.Series[0].TmdbId.Should().Be(1396);
    }

    [Fact]
    public async Task ParseAsync_MapsLiveTvChannels_WhenCollectionTypeIsLiveTv()
    {
        var source = MakeSource();
        const string libraries = """
        {"Items":[{"Id":"lib3","Name":"Live TV","Type":"livetv"}],"TotalRecordCount":1}
        """;
        const string channelItems = """
        {"Items":[{"Id":"ch1","Name":"BBC One","Type":"TvChannel"}],"TotalRecordCount":1}
        """;
        var sut = MakeSut(source, presetToken: "tok",
            (HttpStatusCode.OK, libraries),
            (HttpStatusCode.OK, channelItems));

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
        result.Channels.Should().HaveCount(1);
        result.Channels[0].Title.Should().Be("BBC One");
    }

    [Fact]
    public async Task ParseAsync_SkipsUnknownLibraryType_WithoutError()
    {
        var source = MakeSource();
        const string libraries = """
        {"Items":[{"Id":"lib4","Name":"Music","Type":"music"}],"TotalRecordCount":1}
        """;
        // No items request expected for unknown type — SequentialHttpMessageHandler returns "{}" by default
        var sut = MakeSut(source, presetToken: "tok",
            (HttpStatusCode.OK, libraries));

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
        result.Movies.Should().BeEmpty();
        result.Series.Should().BeEmpty();
        result.Channels.Should().BeEmpty();
    }

    // ─── With username/password auth ──────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_AuthenticatesFirst_WhenUsernameAndPasswordProvided()
    {
        var source = MakeSource(username: "admin", password: "pass");
        const string authResp = """{"AccessToken":"tok_from_auth","UserId":"u1"}""";
        const string emptyLibraries = """{"Items":[],"TotalRecordCount":0}""";
        var sut = MakeSut(source, presetToken: null,
            (HttpStatusCode.OK, authResp),
            (HttpStatusCode.OK, emptyLibraries));

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
    }

    // ─── Connectivity error ───────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_ReturnsError_WhenServerUnreachable()
    {
        var source = MakeSource();

        // Handler throws immediately — simulate unreachable server
        var throwingHandler = new ThrowingHttpHandler(
            new HttpRequestException("Connection refused"));
        var httpClient = new HttpClient(throwingHandler) { BaseAddress = new Uri(source.Url) };
        var enc = new TestCredentialEncryption();

        JellyfinClient ClientFactory(Source s)
            => new(s.Url, "tok", enc, httpClient, NullLogger<JellyfinClient>.Instance);

        var sut = new JellyfinSyncService(ClientFactory, NullLogger<JellyfinSyncService>.Instance);

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("unreachable");
    }

    [Fact]
    public async Task ParseAsync_ReturnsError_WhenUnexpectedExceptionThrown()
    {
        var source = MakeSource();

        var throwingHandler = new ThrowingHttpHandler(
            new InvalidOperationException("Unexpected failure"));
        var httpClient = new HttpClient(throwingHandler) { BaseAddress = new Uri(source.Url) };
        var enc = new TestCredentialEncryption();

        JellyfinClient ClientFactory(Source s)
            => new(s.Url, "tok", enc, httpClient, NullLogger<JellyfinClient>.Instance);

        var sut = new JellyfinSyncService(ClientFactory, NullLogger<JellyfinSyncService>.Instance);

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Be("Unexpected failure");
    }

    // ─── BuildImageUrl ────────────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_MovieThumbnail_IsNull_WhenNoImageTags()
    {
        var source = MakeSource();
        const string libraries = """
        {"Items":[{"Id":"lib1","Name":"Movies","Type":"movies"}],"TotalRecordCount":1}
        """;
        const string movieItems = """
        {"Items":[{"Id":"m2","Name":"No Poster","Type":"Movie"}],"TotalRecordCount":1}
        """;
        var sut = MakeSut(source, presetToken: "tok",
            (HttpStatusCode.OK, libraries),
            (HttpStatusCode.OK, movieItems));

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeTrue();
        result.Movies.Should().HaveCount(1);
        result.Movies[0].Thumbnail.Should().BeNull();
    }

    // ─── IsConnectivityError ──────────────────────────────────────────────────

    [Fact]
    public async Task ParseAsync_ReturnsError_WhenServerReturns503()
    {
        var source = MakeSource();

        var handler = new SequentialHttpMessageHandler(
            (HttpStatusCode.ServiceUnavailable, "{}"));
        var httpClient = new HttpClient(handler) { BaseAddress = new Uri(source.Url) };
        var enc = new TestCredentialEncryption();

        JellyfinClient ClientFactory(Source s)
            => new(s.Url, "tok", enc, httpClient, NullLogger<JellyfinClient>.Instance);

        var sut = new JellyfinSyncService(ClientFactory, NullLogger<JellyfinSyncService>.Instance);

        var result = await sut.ParseAsync(source);

        result.IsSuccess.Should().BeFalse();
    }
}

// ─── Test doubles ─────────────────────────────────────────────────────────────

internal sealed class ThrowingHttpHandler : HttpMessageHandler
{
    private readonly Exception _ex;

    public ThrowingHttpHandler(Exception ex) => _ex = ex;

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
        => Task.FromException<HttpResponseMessage>(_ex);
}
