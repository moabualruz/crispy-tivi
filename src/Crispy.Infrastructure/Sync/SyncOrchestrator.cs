using System.Collections.Concurrent;

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
public sealed class SyncOrchestrator : ISyncOrchestrator, ISyncService, IHostedService
{
    private readonly ISourceRepository _sourceRepository;
    private readonly IReadOnlyDictionary<SourceType, ISourceParser> _parsers;
    private readonly SyncPipeline _pipeline;
    private readonly ChannelDeduplicator _deduplicator;
    private readonly SyncScheduler _scheduler;
    private readonly ILogger<SyncOrchestrator> _logger;

    private CancellationTokenSource? _startupCts;
    private readonly ConcurrentDictionary<int, SemaphoreSlim> _sourceLocks = new();

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

        Console.WriteLine($"[SYNC] SyncAllAsync: {enabledSources.Count} enabled sources out of {sources.Count()} total");
        _logger.LogInformation("Syncing {Count} sources", enabledSources.Count);

        var tasks = enabledSources.Select(s => SyncSourceAsync(s.Id, ct));
        await Task.WhenAll(tasks).ConfigureAwait(false);
        Console.WriteLine("[SYNC] SyncAllAsync complete");
    }

    /// <inheritdoc />
    public Task CancelAsync(int sourceId)
    {
        _logger.LogInformation("Cancel requested for source {SourceId} (not yet implemented)", sourceId);
        return Task.CompletedTask;
    }

    /// <summary>Syncs a single source by ID. Per-source lock prevents concurrent duplicate syncs.</summary>
    public async Task SyncSourceAsync(int sourceId, CancellationToken ct = default)
    {
        Console.WriteLine($"[SYNC] SyncSourceAsync({sourceId}) called");
        var semaphore = _sourceLocks.GetOrAdd(sourceId, _ => new SemaphoreSlim(1, 1));
        if (!await semaphore.WaitAsync(0, ct).ConfigureAwait(false))
        {
            Console.WriteLine($"[SYNC] Source {sourceId} already syncing, skipped");
            _logger.LogInformation("Sync already in progress for source {SourceId}, skipping", sourceId);
            return;
        }

        try
        {
            var source = await _sourceRepository.GetByIdAsync(sourceId).ConfigureAwait(false);
            if (source is null)
            {
                Console.WriteLine($"[SYNC] Source {sourceId} NOT FOUND in DB");
                _logger.LogWarning("Source {SourceId} not found", sourceId);
                return;
            }

            Console.WriteLine($"[SYNC] Source {sourceId}: Name={source.Name}, Type={source.SourceType}, Url={source.Url}");

            if (!_parsers.TryGetValue(source.SourceType, out var parser))
            {
                Console.WriteLine($"[SYNC] No parser for SourceType {source.SourceType}");
                _logger.LogWarning("No parser registered for SourceType {Type}", source.SourceType);
                return;
            }

            Console.WriteLine($"[SYNC] Starting pipeline for source {sourceId} with parser {parser.GetType().Name}");
            _logger.LogInformation("Syncing source {SourceId} ({Name})", sourceId, source.Name);
            await _pipeline.RunAsync(source, parser, ct).ConfigureAwait(false);
            Console.WriteLine($"[SYNC] Pipeline complete for source {sourceId}, running deduplicator");
            await _deduplicator.RunAsync(ct).ConfigureAwait(false);
            Console.WriteLine($"[SYNC] Sync complete for source {sourceId}");
            _logger.LogInformation("Sync complete for source {SourceId}", sourceId);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            Console.WriteLine($"[SYNC] EXCEPTION for source {sourceId}: {ex}");
            _logger.LogError(ex, "Sync failed for source {SourceId}", sourceId);
        }
        finally
        {
            semaphore.Release();
        }
    }
}
