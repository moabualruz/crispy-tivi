using Crispy.Application.Sources;
using Crispy.Application.Sync;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Sync;

/// <summary>
/// Hosted service that triggers an immediate sync on app startup, then delegates to SyncScheduler.
/// Implements ISyncOrchestrator for manual trigger support.
/// </summary>
public sealed class SyncOrchestrator : ISyncOrchestrator, IHostedService
{
    private readonly ISourceRepository _sourceRepository;
    private readonly IReadOnlyDictionary<SourceType, ISourceParser> _parsers;
    private readonly SyncPipeline _pipeline;
    private readonly ChannelDeduplicator _deduplicator;
    private readonly SyncScheduler _scheduler;
    private readonly ILogger<SyncOrchestrator> _logger;

    private CancellationTokenSource? _startupCts;

    /// <summary>Creates a new SyncOrchestrator.</summary>
    public SyncOrchestrator(
        ISourceRepository sourceRepository,
        IReadOnlyDictionary<SourceType, ISourceParser> parsers,
        SyncPipeline pipeline,
        ChannelDeduplicator deduplicator,
        SyncScheduler scheduler,
        ILogger<SyncOrchestrator> logger)
    {
        _sourceRepository = sourceRepository;
        _parsers = parsers;
        _pipeline = pipeline;
        _deduplicator = deduplicator;
        _scheduler = scheduler;
        _logger = logger;
    }

    // ─── IHostedService ───────────────────────────────────────────────────────

    /// <inheritdoc />
    Task IHostedService.StartAsync(CancellationToken cancellationToken)
    {
        _startupCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var token = _startupCts.Token;

        // Fire-and-forget: startup sync then hand off to scheduler
        _ = Task.Run(async () =>
        {
            try
            {
                await SyncAllAsync(token).ConfigureAwait(false);
                await _scheduler.StartAsync(token).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Startup sync cancelled");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Startup sync failed");
            }
        }, token);

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    Task IHostedService.StopAsync(CancellationToken cancellationToken)
    {
        return StopAsync();
    }

    // ─── ISyncOrchestrator ────────────────────────────────────────────────────

    /// <inheritdoc />
    public async Task StartAsync(CancellationToken ct = default)
    {
        await SyncAllAsync(ct).ConfigureAwait(false);
        await _scheduler.StartAsync(ct).ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task StopAsync()
    {
        if (_startupCts is not null)
            await _startupCts.CancelAsync().ConfigureAwait(false);

        await _scheduler.StopAsync().ConfigureAwait(false);
    }

    // ─── Core sync logic ──────────────────────────────────────────────────────

    /// <summary>Syncs all enabled sources concurrently.</summary>
    public async Task SyncAllAsync(CancellationToken ct = default)
    {
        var sources = await _sourceRepository.GetAllAsync().ConfigureAwait(false);
        var enabledSources = sources.Where(s => s.IsEnabled).ToList();

        _logger.LogInformation("Syncing {Count} sources", enabledSources.Count);

        var tasks = enabledSources.Select(s => SyncSourceAsync(s.Id, ct));
        await Task.WhenAll(tasks).ConfigureAwait(false);
    }

    /// <summary>Syncs a single source by ID.</summary>
    public async Task SyncSourceAsync(int sourceId, CancellationToken ct = default)
    {
        try
        {
            var source = await _sourceRepository.GetByIdAsync(sourceId).ConfigureAwait(false);
            if (source is null)
            {
                _logger.LogWarning("Source {SourceId} not found", sourceId);
                return;
            }

            if (!_parsers.TryGetValue(source.SourceType, out var parser))
            {
                _logger.LogWarning("No parser registered for SourceType {Type}", source.SourceType);
                return;
            }

            await _pipeline.RunAsync(source, parser, ct).ConfigureAwait(false);
            await _deduplicator.RunAsync(ct).ConfigureAwait(false);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogError(ex, "Sync failed for source {SourceId}", sourceId);
        }
    }
}
