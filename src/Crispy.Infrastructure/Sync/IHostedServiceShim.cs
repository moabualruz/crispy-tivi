// ReSharper disable once CheckNamespace
namespace Microsoft.Extensions.Hosting;

/// <summary>
/// Local shim of IHostedService for projects where Microsoft.Extensions.Hosting.Abstractions
/// is not available via NuGet restore. Matches the BCL interface exactly.
/// When the real package is available this shim should be removed.
/// </summary>
public interface IHostedService
{
    /// <summary>Triggered when the application host is ready to start the service.</summary>
    Task StartAsync(CancellationToken cancellationToken);

    /// <summary>Triggered when the application host is performing a graceful shutdown.</summary>
    Task StopAsync(CancellationToken cancellationToken);
}
