using System.Net.NetworkInformation;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Connectivity;

/// <summary>
/// 4-tier connectivity monitor.
/// Tier 1: NetworkInterface.GetIsNetworkAvailable()
/// Tier 2: HEAD https://1.1.1.1 with 2s timeout
/// Tier 3: HEAD {sourceUrl} with 3s timeout
/// </summary>
public sealed class ConnectivityMonitor : IConnectivityMonitor, IDisposable
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<ConnectivityMonitor> _logger;

    /// <inheritdoc />
    public ConnectivityLevel CurrentLevel { get; private set; } = ConnectivityLevel.Online;

    /// <inheritdoc />
    public event EventHandler<ConnectivityLevel>? ConnectivityChanged;

    private static readonly Uri CloudflareProbe = new("https://1.1.1.1");

    /// <summary>Creates a new ConnectivityMonitor.</summary>
    public ConnectivityMonitor(HttpClient httpClient, ILogger<ConnectivityMonitor> logger)
    {
        _httpClient = httpClient;
        _logger = logger;

        NetworkChange.NetworkAvailabilityChanged += OnNetworkAvailabilityChanged;
    }

    /// <inheritdoc />
    public async Task<ConnectivityLevel> CheckAsync(Uri? sourceUrl = null, CancellationToken ct = default)
    {
        // Tier 1: device-level network available?
        if (!NetworkInterface.GetIsNetworkAvailable())
        {
            return UpdateLevel(ConnectivityLevel.DeviceOffline);
        }

        // Tier 2: internet reachable (1.1.1.1)?
        if (!await ProbeUrlAsync(CloudflareProbe, timeout: TimeSpan.FromSeconds(2), ct).ConfigureAwait(false))
        {
            return UpdateLevel(ConnectivityLevel.InternetUnreachable);
        }

        // Tier 3: specific source reachable?
        if (sourceUrl is not null &&
            !await ProbeUrlAsync(sourceUrl, timeout: TimeSpan.FromSeconds(3), ct).ConfigureAwait(false))
        {
            return UpdateLevel(ConnectivityLevel.SourceDown);
        }

        return UpdateLevel(ConnectivityLevel.Online);
    }

    private async Task<bool> ProbeUrlAsync(Uri url, TimeSpan timeout, CancellationToken ct)
    {
        try
        {
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(timeout);

            using var request = new HttpRequestMessage(HttpMethod.Head, url);
            using var response = await _httpClient.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cts.Token).ConfigureAwait(false);

            return response.IsSuccessStatusCode || (int)response.StatusCode < 500;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or OperationCanceledException)
        {
            _logger.LogDebug("Probe failed for {Url}: {Message}", url, ex.Message);
            return false;
        }
    }

    private ConnectivityLevel UpdateLevel(ConnectivityLevel level)
    {
        if (level != CurrentLevel)
        {
            CurrentLevel = level;
            ConnectivityChanged?.Invoke(this, level);
        }
        return level;
    }

    internal void OnNetworkAvailabilityChanged(object? sender, NetworkAvailabilityEventArgs e)
    {
        // Fire-and-forget re-check on network change
        _ = Task.Run(async () =>
        {
            try { await CheckAsync().ConfigureAwait(false); }
            catch { /* ignore */ }
        });
    }

    /// <inheritdoc />
    public void Dispose()
    {
        NetworkChange.NetworkAvailabilityChanged -= OnNetworkAvailabilityChanged;
    }
}
