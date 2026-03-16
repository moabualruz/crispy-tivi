using System.Net.NetworkInformation;
using System.Text.Json;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Parsers.Stalker;

/// <summary>
/// HTTP client for Stalker Portal (Ministra/MAG) middleware.
/// Handles token handshake, MAC auto-detection, and on-demand keep-alive.
/// </summary>
public sealed class StalkerClient : IAsyncDisposable
{
    private readonly HttpClient _http;
    private CancellationTokenSource? _keepAliveCts;
    private Task? _keepAliveTask;

    /// <summary>The MAC address used in all requests.</summary>
    public string Mac { get; }

    private string? _token;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    /// <summary>
    /// Creates a new StalkerClient.
    /// </summary>
    /// <param name="httpClient">Named HTTP client with base address set to portal URL.</param>
    /// <param name="mac">
    /// MAC address to use. If null, auto-detects the first non-loopback physical MAC.
    /// Falls back to "00:00:00:00:00:00" if no physical interface found.
    /// </param>
    public StalkerClient(HttpClient httpClient, string? mac = null)
    {
        _http = httpClient;
        Mac = mac ?? DetectMac();
    }

    /// <summary>
    /// Sets the base address of the underlying HttpClient to the given portal URL.
    /// Must be called before every sync so the client targets the correct source.
    /// Resets the cached token so a fresh handshake is performed for the new URL.
    /// </summary>
    public void SetBaseAddress(string url)
    {
        var uri = new Uri(url.TrimEnd('/') + "/");
        if (_http.BaseAddress != uri)
        {
            _http.BaseAddress = uri;
            _token = null; // force re-handshake for new portal
        }
    }

    /// <summary>
    /// Performs the initial handshake to obtain an authentication token.
    /// </summary>
    public async Task<string?> HandshakeAsync(CancellationToken ct = default)
    {
        using var response = await _http.GetAsync(
            $"/portal.php?action=handshake&type=stb&token=&JsHttpRequest=1-xml&mac={Uri.EscapeDataString(Mac)}",
            ct).ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
            return null;

        await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: ct).ConfigureAwait(false);

        if (doc.RootElement.TryGetProperty("js", out var js) &&
            js.TryGetProperty("token", out var tok))
        {
            _token = tok.GetString();
        }

        return _token;
    }

    /// <summary>Returns the profile info for the authenticated user.</summary>
    public Task<JsonDocument?> GetProfileAsync(CancellationToken ct = default)
        => GetAuthorizedAsync("/portal.php?type=stb&action=get_profile&JsHttpRequest=1-xml", ct);

    /// <summary>Returns all channels from the Stalker portal.</summary>
    public Task<JsonDocument?> GetChannelsAsync(CancellationToken ct = default)
        => GetAuthorizedAsync("/portal.php?type=itv&action=get_all_channels&JsHttpRequest=1-xml", ct);

    /// <summary>Returns VOD categories.</summary>
    public Task<JsonDocument?> GetVodCategoriesAsync(CancellationToken ct = default)
        => GetAuthorizedAsync("/portal.php?type=vod&action=get_categories&JsHttpRequest=1-xml", ct);

    /// <summary>Returns VOD items for a category.</summary>
    public Task<JsonDocument?> GetVodListAsync(string categoryId, int page = 1, CancellationToken ct = default)
        => GetAuthorizedAsync(
            $"/portal.php?type=vod&action=get_ordered_list&category={categoryId}&p={page}&JsHttpRequest=1-xml",
            ct);

    /// <summary>
    /// Starts the keep-alive background ping. Call only during active Stalker browsing.
    /// </summary>
    /// <param name="interval">Ping interval. Defaults to 90 seconds.</param>
    public async Task StartKeepAliveAsync(TimeSpan? interval = null, CancellationToken ct = default)
    {
        await StopKeepAliveAsync().ConfigureAwait(false);

        _keepAliveCts = new CancellationTokenSource();
        var token = _keepAliveCts.Token;
        var pingInterval = interval ?? TimeSpan.FromSeconds(90);

        _keepAliveTask = Task.Run(async () =>
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(pingInterval, token).ConfigureAwait(false);
                    if (!token.IsCancellationRequested)
                    {
                        await GetAuthorizedAsync("/portal.php?type=watchdog&action=ping&JsHttpRequest=1-xml", token)
                            .ConfigureAwait(false);
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch
                {
                    // Ignore ping failures — keep-alive is best-effort
                }
            }
        }, token);
    }

    /// <summary>Stops the keep-alive background ping.</summary>
    public async Task StopKeepAliveAsync()
    {
        if (_keepAliveCts is not null)
        {
            await _keepAliveCts.CancelAsync().ConfigureAwait(false);
            if (_keepAliveTask is not null)
            {
                try { await _keepAliveTask.ConfigureAwait(false); }
                catch (OperationCanceledException) { }
            }
            _keepAliveCts.Dispose();
            _keepAliveCts = null;
            _keepAliveTask = null;
        }
    }

    private async Task<JsonDocument?> GetAuthorizedAsync(string relativeUrl, CancellationToken ct)
    {
        if (_token is null)
            await HandshakeAsync(ct).ConfigureAwait(false);

        using var request = new HttpRequestMessage(HttpMethod.Get, relativeUrl);
        request.Headers.TryAddWithoutValidation("Authorization", $"Bearer {_token}");
        request.Headers.TryAddWithoutValidation("X-User-Agent", $"Model: MAG254; Link: WiFi");

        using var response = await _http.SendAsync(request, ct).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
            return null;

        await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
        return await JsonDocument.ParseAsync(stream, cancellationToken: ct).ConfigureAwait(false);
    }

    private static string DetectMac()
    {
        var ni = NetworkInterface.GetAllNetworkInterfaces()
            .FirstOrDefault(n =>
                n.OperationalStatus == OperationalStatus.Up &&
                n.NetworkInterfaceType != NetworkInterfaceType.Loopback &&
                n.GetPhysicalAddress().GetAddressBytes().Length == 6);

        if (ni is null)
            return "00:00:00:00:00:00";

        var bytes = ni.GetPhysicalAddress().GetAddressBytes();
        return string.Join(":", bytes.Select(b => b.ToString("X2")));
    }

    /// <inheritdoc />
    public async ValueTask DisposeAsync()
    {
        await StopKeepAliveAsync().ConfigureAwait(false);
        _http.Dispose();
    }
}
