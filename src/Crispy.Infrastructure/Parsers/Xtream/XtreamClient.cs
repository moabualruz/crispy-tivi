using System.Text.Json;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Parsers.Xtream;

/// <summary>
/// Typed HTTP client for the Xtream Codes JSON API.
/// </summary>
public sealed class XtreamClient
{
    private readonly HttpClient _http;
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    /// <summary>The last successful authentication response.</summary>
    public XtreamAuthResponse? LastAuthResponse { get; private set; }

    /// <summary>Creates a new XtreamClient with the given HttpClient.</summary>
    public XtreamClient(HttpClient httpClient)
    {
        _http = httpClient;
    }

    /// <summary>
    /// Authenticates against the Xtream Codes API and stores the server/user info.
    /// Returns null if the request fails.
    /// </summary>
    public async Task<XtreamAuthResponse?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken ct = default)
    {
        var url = $"/player_api.php?username={Uri.EscapeDataString(username)}&password={Uri.EscapeDataString(password)}";
        using var response = await _http.GetAsync(url, ct).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        var auth = await JsonSerializer.DeserializeAsync<XtreamAuthResponse>(stream, JsonOpts, ct)
            .ConfigureAwait(false);

        LastAuthResponse = auth;
        return auth;
    }

    /// <summary>Returns live stream list from the API.</summary>
    public async Task<JsonDocument?> GetLiveStreamsAsync(
        string username,
        string password,
        CancellationToken ct = default)
        => await GetJsonAsync($"/player_api.php?username={username}&password={password}&action=get_live_streams", ct)
            .ConfigureAwait(false);

    /// <summary>Returns VOD stream list from the API.</summary>
    public async Task<JsonDocument?> GetVodStreamsAsync(
        string username,
        string password,
        CancellationToken ct = default)
        => await GetJsonAsync($"/player_api.php?username={username}&password={password}&action=get_vod_streams", ct)
            .ConfigureAwait(false);

    /// <summary>Returns series list from the API (list only — no season/episode detail).</summary>
    public async Task<JsonDocument?> GetSeriesAsync(
        string username,
        string password,
        CancellationToken ct = default)
        => await GetJsonAsync($"/player_api.php?username={username}&password={password}&action=get_series", ct)
            .ConfigureAwait(false);

    /// <summary>Returns short EPG (now/next) for a stream.</summary>
    public async Task<JsonDocument?> GetEpgAsync(
        string username,
        string password,
        string streamId,
        CancellationToken ct = default)
        => await GetJsonAsync(
            $"/player_api.php?username={username}&password={password}&action=get_short_epg&stream_id={streamId}",
            ct).ConfigureAwait(false);

    /// <summary>
    /// Downloads the M3U playlist from the given absolute URL using the same HttpClient instance.
    /// This keeps the M3U fallback testable via the injected HttpClient.
    /// </summary>
    public Task<Stream> GetM3UStreamAsync(string absoluteUrl, CancellationToken ct = default)
        => _http.GetStreamAsync(absoluteUrl, ct);

    private async Task<JsonDocument?> GetJsonAsync(string relativeUrl, CancellationToken ct)
    {
        using var response = await _http.GetAsync(relativeUrl, ct).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
            return null;

        await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        return await JsonDocument.ParseAsync(stream, cancellationToken: ct).ConfigureAwait(false);
    }
}
