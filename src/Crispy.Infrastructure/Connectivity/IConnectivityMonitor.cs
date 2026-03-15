namespace Crispy.Infrastructure.Connectivity;

/// <summary>
/// Monitors network connectivity at four levels of granularity.
/// </summary>
public interface IConnectivityMonitor
{
    /// <summary>
    /// Checks current connectivity, optionally verifying reachability of a specific source URL.
    /// </summary>
    Task<ConnectivityLevel> CheckAsync(Uri? sourceUrl = null, CancellationToken ct = default);

    /// <summary>Current connectivity level (cached from last check).</summary>
    ConnectivityLevel CurrentLevel { get; }

    /// <summary>Raised when connectivity level changes.</summary>
    event EventHandler<ConnectivityLevel>? ConnectivityChanged;
}

/// <summary>
/// Connectivity tier classification from best to worst.
/// </summary>
public enum ConnectivityLevel
{
    /// <summary>All tiers reachable (device, internet, source).</summary>
    Online = 0,

    /// <summary>Device online and internet reachable, but the specific source is down.</summary>
    SourceDown = 1,

    /// <summary>Device has a network adapter up but no internet access (DNS/gateway failure).</summary>
    InternetUnreachable = 2,

    /// <summary>No network interface is available (device offline / airplane mode).</summary>
    DeviceOffline = 3,
}
