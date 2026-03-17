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

    /// <summary>The server base URL set by the parser before each sync.</summary>
    public string? BaseUrl { get; set; }

    /// <summary>
    /// Authenticates against the Xtream Codes API and stores the server/user info.
    /// Returns null if the request fails.
    /// </summary>
    public async Task<XtreamAuthResponse?> AuthenticateAsync(
        string username,
        string password,
        CancellationToken ct = default)
    {
        var baseUrl = BaseUrl?.TrimEnd('/') ?? throw new InvalidOperationException("BaseUrl must be set before calling AuthenticateAsync");
        var url = $"{baseUrl}/player_api.php?username={Uri.EscapeDataString(username)}&password={Uri.EscapeDataString(password)}";
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

    /// <summary>Returns detailed series info including seasons and episodes.</summary>
    public async Task<JsonDocument?> GetSeriesInfoAsync(
        string username,
        string password,
        string seriesId,
        CancellationToken ct = default)
        => await GetJsonAsync(
            $"/player_api.php?username={Uri.EscapeDataString(username)}&password={Uri.EscapeDataString(password)}&action=get_series_info&series_id={seriesId}",
            ct).ConfigureAwait(false);

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
        var url = (BaseUrl?.TrimEnd('/') ?? string.Empty) + relativeUrl;
        Console.WriteLine($"[HTTP] GET {url}");
        using var response = await _http.GetAsync(url, ct).ConfigureAwait(false);
        Console.WriteLine($"[HTTP] Status={response.StatusCode}, ContentLength={response.Content.Headers.ContentLength?.ToString() ?? "null"}, ContentType={response.Content.Headers.ContentType}");
        if (!response.IsSuccessStatusCode)
            return null;

        // Read as bytes to diagnose Android HTTP handler differences
        var bytes = await response.Content.ReadAsByteArrayAsync(ct).ConfigureAwait(false);
        Console.WriteLine($"[HTTP] Received {bytes.Length} bytes, first='{(char)bytes[0]}', last='{(char)bytes[^1]}'");

        try
        {
            using var memStream = new MemoryStream(bytes);
            return await JsonDocument.ParseAsync(memStream, cancellationToken: ct).ConfigureAwait(false);
        }
        catch (System.Text.Json.JsonException ex)
        {
            // Dump context around the error position
            var pos = (int)(ex.BytePositionInLine ?? 0);
            var start = Math.Max(0, pos - 50);
            var len = Math.Min(100, bytes.Length - start);
            var context = System.Text.Encoding.UTF8.GetString(bytes, start, len);
            Console.WriteLine($"[HTTP] JSON parse failed at byte {pos}. Context: ...{context}...");
            throw;
        }
    }
}
