using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.ValueObjects;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Sync;  // IHostedServiceShim

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Downloads;

/// <summary>
/// Manages the offline download queue. Enforces a maximum of 2 concurrent downloads.
/// Implements IHostedServiceShim so it can be started by the platform host.
/// </summary>
public sealed class DownloadManager : IHostedService
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;
    private readonly ILogger<DownloadManager> _logger;

    private readonly SemaphoreSlim _concurrencySlot = new(2, 2);
    private CancellationTokenSource? _cts;
    private Task? _backgroundTask;

    // Storage budgets
    private const long DesktopBudgetBytes = 2L * 1024 * 1024 * 1024;   // 2 GB
    private const long MobileBudgetBytes = 1L * 1024 * 1024 * 1024;    // 1 GB

    /// <summary>Creates a new DownloadManager.</summary>
    public DownloadManager(IDbContextFactory<AppDbContext> dbFactory, ILogger<DownloadManager> logger)
    {
        _dbFactory = dbFactory;
        _logger = logger;
    }

    // ─── IHostedServiceShim ───────────────────────────────────────────────────

    /// <inheritdoc/>
    public Task StartAsync(CancellationToken cancellationToken)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _backgroundTask = Task.Run(() => ProcessQueueAsync(_cts.Token), _cts.Token);
        _logger.LogInformation("DownloadManager started");
        return Task.CompletedTask;
    }

    /// <inheritdoc/>
    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_cts is not null)
            await _cts.CancelAsync().ConfigureAwait(false);

        if (_backgroundTask is not null)
            await _backgroundTask.ConfigureAwait(false);

        _logger.LogInformation("DownloadManager stopped");
    }

    // ─── Queue management ─────────────────────────────────────────────────────

    /// <summary>
    /// Queues a new download for the specified content item.
    /// </summary>
    public async Task<int> QueueDownloadAsync(ContentReference content, string quality, CancellationToken ct = default)
    {
        await using var ctx = await _dbFactory.CreateDbContextAsync(ct).ConfigureAwait(false);

        var downloadsDir = GetDownloadsDirectory();
        var fileName = $"{content.ContentType}_{content.ContentId}_{quality}.mp4";
        var filePath = Path.Combine(downloadsDir, fileName);

        var download = new Download
        {
            ContentType = content.ContentType,
            ContentId = content.ContentId,
            Status = DownloadStatus.Queued,
            Quality = quality,
            FilePath = filePath,
        };

        ctx.Downloads.Add(download);
        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);

        _logger.LogInformation("Queued download {DownloadId} for {ContentType}/{ContentId}",
            download.Id, content.ContentType, content.ContentId);

        return download.Id;
    }

    /// <summary>
    /// Pauses an active download.
    /// </summary>
    public async Task PauseAsync(int downloadId, CancellationToken ct = default)
    {
        await UpdateStatusAsync(downloadId, DownloadStatus.Paused, ct).ConfigureAwait(false);
    }

    /// <summary>
    /// Resumes a paused download.
    /// </summary>
    public async Task ResumeAsync(int downloadId, CancellationToken ct = default)
    {
        await UpdateStatusAsync(downloadId, DownloadStatus.Queued, ct).ConfigureAwait(false);
    }

    /// <summary>
    /// Cancels a download.
    /// </summary>
    public async Task CancelAsync(int downloadId, CancellationToken ct = default)
    {
        await using var ctx = await _dbFactory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var download = await ctx.Downloads.FindAsync([downloadId], ct).ConfigureAwait(false);
        if (download is null)
            return;

        download.Status = DownloadStatus.Failed;
        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
        _logger.LogInformation("Cancelled download {DownloadId}", downloadId);
    }

    /// <summary>
    /// Gets all downloads for the specified content item.
    /// </summary>
    public async Task<IReadOnlyList<Download>> GetDownloadsAsync(CancellationToken ct = default)
    {
        await using var ctx = await _dbFactory.CreateDbContextAsync(ct).ConfigureAwait(false);
        return await ctx.Downloads
            .Where(d => d.Status != DownloadStatus.Failed)
            .OrderBy(d => d.CreatedAt)
            .ToListAsync(ct)
            .ConfigureAwait(false);
    }

    // ─── Background processing ────────────────────────────────────────────────

    /// <summary>
    /// Background loop: picks queued downloads and processes up to 2 concurrently.
    /// </summary>
    public async Task ProcessQueueAsync(CancellationToken ct = default)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                await using var ctx = await _dbFactory.CreateDbContextAsync(ct).ConfigureAwait(false);

                var queued = await ctx.Downloads
                    .Where(d => d.Status == DownloadStatus.Queued)
                    .OrderBy(d => d.CreatedAt)
                    .ToListAsync(ct)
                    .ConfigureAwait(false);

                foreach (var download in queued)
                {
                    if (ct.IsCancellationRequested)
                        break;

                    // Try to acquire a concurrency slot without blocking — skip if full
                    if (!_concurrencySlot.Wait(0))
                        break;

                    download.Status = DownloadStatus.Downloading;
                    await ctx.SaveChangesAsync(ct).ConfigureAwait(false);

                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            await ExecuteDownloadAsync(download.Id, ct).ConfigureAwait(false);
                        }
                        finally
                        {
                            _concurrencySlot.Release();
                        }
                    }, ct);
                }

                // Poll interval
                await Task.Delay(TimeSpan.FromSeconds(5), ct).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Download queue processing error");
                await Task.Delay(TimeSpan.FromSeconds(10), ct).ConfigureAwait(false);
            }
        }
    }

    // ─── Internals ────────────────────────────────────────────────────────────

    private async Task ExecuteDownloadAsync(int downloadId, CancellationToken ct)
    {
        // Phase 2: manages queue state only — actual byte transfer implemented in Phase 3 (player integration)
        _logger.LogInformation("Download {DownloadId} started (byte transfer deferred to Phase 3)", downloadId);

        // Placeholder: simulate the download completing for now
        // In Phase 3 this will be replaced with actual HLS/HTTP streaming download
        await Task.Delay(100, ct).ConfigureAwait(false);

        await UpdateStatusAsync(downloadId, DownloadStatus.Completed, ct).ConfigureAwait(false);
    }

    private async Task UpdateStatusAsync(int downloadId, DownloadStatus status, CancellationToken ct)
    {
        await using var ctx = await _dbFactory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var download = await ctx.Downloads.FindAsync([downloadId], ct).ConfigureAwait(false);
        if (download is null)
            return;

        download.Status = status;
        await ctx.SaveChangesAsync(ct).ConfigureAwait(false);
    }

    private static string GetDownloadsDirectory()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CrispyTivi", "Downloads");
        Directory.CreateDirectory(dir);
        return dir;
    }
}
