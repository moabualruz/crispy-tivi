using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Sync;

/// <summary>
/// Periodic timer that triggers SyncOrchestrator.SyncAllAsync on a configurable interval.
/// Default: 4-hour interval.
/// </summary>
public sealed class SyncScheduler : IAsyncDisposable
{
    private readonly Func<CancellationToken, Task> _syncAllCallback;
    private readonly TimeSpan _interval;
    private readonly ILogger<SyncScheduler> _logger;

    private CancellationTokenSource? _cts;
    private Task? _timerTask;

    /// <summary>Creates a new SyncScheduler.</summary>
    /// <param name="syncAllCallback">Callback invoked on each tick (typically SyncOrchestrator.SyncAllAsync).</param>
    /// <param name="interval">Sync interval. Defaults to 4 hours.</param>
    /// <param name="logger">Logger instance.</param>
    public SyncScheduler(
        Func<CancellationToken, Task> syncAllCallback,
        ILogger<SyncScheduler> logger,
        TimeSpan? interval = null)
    {
        _syncAllCallback = syncAllCallback;
        _interval = interval ?? TimeSpan.FromHours(4);
        _logger = logger;
    }

    /// <summary>Starts the periodic sync timer.</summary>
    public Task StartAsync(CancellationToken ct = default)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var token = _cts.Token;

        _timerTask = Task.Run(async () =>
        {
            using var timer = new PeriodicTimer(_interval);

            while (await timer.WaitForNextTickAsync(token).ConfigureAwait(false))
            {
                try
                {
                    _logger.LogInformation("Scheduled sync starting");
                    await _syncAllCallback(token).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Scheduled sync failed");
                }
            }
        }, token);

        return Task.CompletedTask;
    }

    /// <summary>Stops the periodic sync timer.</summary>
    public async Task StopAsync()
    {
        if (_cts is not null)
        {
            await _cts.CancelAsync().ConfigureAwait(false);
            if (_timerTask is not null)
            {
                try { await _timerTask.ConfigureAwait(false); }
                catch (OperationCanceledException) { }
            }
            _cts.Dispose();
            _cts = null;
        }
    }

    /// <inheritdoc />
    public async ValueTask DisposeAsync() => await StopAsync().ConfigureAwait(false);
}
