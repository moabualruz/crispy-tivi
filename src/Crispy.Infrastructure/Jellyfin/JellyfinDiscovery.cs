using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Jellyfin;

/// <summary>
/// Info about a discovered Jellyfin server on the LAN.
/// </summary>
public sealed class JellyfinServerInfo
{
    /// <summary>Server address (URL).</summary>
    public string Address { get; init; } = string.Empty;

    /// <summary>Unique server ID.</summary>
    public string Id { get; init; } = string.Empty;

    /// <summary>Human-readable server name.</summary>
    public string Name { get; init; } = string.Empty;

    /// <summary>Endpoint address reported by the server.</summary>
    public string EndpointAddress { get; init; } = string.Empty;
}

/// <summary>
/// Discovers Jellyfin servers on the local network via UDP broadcast,
/// and validates manually entered server URLs.
/// </summary>
public sealed class JellyfinDiscovery
{
    private const int JellyfinBroadcastPort = 7359;
    private const string DiscoveryPayload = "who is JellyfinServer?";

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<JellyfinDiscovery> _logger;

    /// <summary>Creates a new JellyfinDiscovery instance.</summary>
    public JellyfinDiscovery(IHttpClientFactory httpClientFactory, ILogger<JellyfinDiscovery> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    /// <summary>
    /// Sends a UDP broadcast to discover Jellyfin servers on the LAN.
    /// Listens for 3 seconds for responses.
    /// </summary>
    public async Task<IReadOnlyList<JellyfinServerInfo>> DiscoverAsync(CancellationToken ct = default)
    {
        var servers = new List<JellyfinServerInfo>();

        try
        {
            using var udpClient = new UdpClient();
            udpClient.EnableBroadcast = true;
            udpClient.Client.Bind(new IPEndPoint(IPAddress.Any, 0));

            var payload = Encoding.UTF8.GetBytes(DiscoveryPayload);
            var broadcastEndpoint = new IPEndPoint(IPAddress.Broadcast, JellyfinBroadcastPort);
            await udpClient.SendAsync(payload, broadcastEndpoint, ct).ConfigureAwait(false);

            // Listen for 3 seconds
            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeoutCts.CancelAfter(TimeSpan.FromSeconds(3));

            while (!timeoutCts.Token.IsCancellationRequested)
            {
                try
                {
                    var result = await udpClient.ReceiveAsync(timeoutCts.Token).ConfigureAwait(false);
                    var json = Encoding.UTF8.GetString(result.Buffer);

                    var info = ParseServerInfo(json);
                    if (info is not null)
                        servers.Add(info);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogWarning(ex, "UDP discovery failed");
        }

        return servers.OrderBy(s => s.Name).ToList();
    }

    /// <summary>
    /// Validates a manually entered server URL by sending a HEAD request to /health.
    /// Returns true if the server responded with HTTP 200.
    /// </summary>
    public async Task<bool> ValidateServerAsync(string url, CancellationToken ct = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient("JellyfinDiscovery");
            var healthUrl = url.TrimEnd('/') + "/health";
            var response = await client.SendAsync(
                new HttpRequestMessage(HttpMethod.Head, healthUrl), ct).ConfigureAwait(false);
            return response.IsSuccessStatusCode;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogDebug(ex, "Server validation failed for {Url}", url);
            return false;
        }
    }

    private static JellyfinServerInfo? ParseServerInfo(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            return new JellyfinServerInfo
            {
                Address = root.TryGetProperty("Address", out var addr) ? addr.GetString() ?? string.Empty : string.Empty,
                Id = root.TryGetProperty("Id", out var id) ? id.GetString() ?? string.Empty : string.Empty,
                Name = root.TryGetProperty("Name", out var name) ? name.GetString() ?? string.Empty : string.Empty,
                EndpointAddress = root.TryGetProperty("EndpointAddress", out var ep) ? ep.GetString() ?? string.Empty : string.Empty,
            };
        }
        catch
        {
            return null;
        }
    }
}
