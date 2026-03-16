using Crispy.Domain.Enums;
using Crispy.Domain.ValueObjects;
using Crispy.Infrastructure.Downloads;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Downloads;

[Trait("Category", "Unit")]
public class DownloadManagerTests : IDisposable
{
    // ─── Setup ────────────────────────────────────────────────────────────────

    private readonly TestDbContextFactory _factory;

    public DownloadManagerTests()
    {
        _factory = new TestDbContextFactory();
    }

    public void Dispose() => _factory.Dispose();

    private DownloadManager CreateSut()
        => new(_factory, NullLogger<DownloadManager>.Instance);

    private static ContentReference MakeContent(ContentType type = ContentType.Movie, int id = 1)
        => new(type, id);

    // ─── QueueDownloadAsync ───────────────────────────────────────────────────

    [Fact]
    public async Task QueueDownloadAsync_ReturnsPositiveId_WhenQueued()
    {
        var sut = CreateSut();
        var content = MakeContent();

        var id = await sut.QueueDownloadAsync(content, "1080p");

        id.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task QueueDownloadAsync_PersistsDownload_WithQueuedStatus()
    {
        var sut = CreateSut();
        var content = MakeContent(ContentType.Episode, 42);

        var id = await sut.QueueDownloadAsync(content, "720p");

        using var ctx = _factory.CreateDbContext();
        var download = ctx.Downloads.Find(id);
        download.Should().NotBeNull();
        download!.Status.Should().Be(DownloadStatus.Queued);
        download.ContentId.Should().Be(42);
        download.ContentType.Should().Be(ContentType.Episode);
        download.Quality.Should().Be("720p");
    }

    [Fact]
    public async Task QueueDownloadAsync_AssignsFilePath_ContainingContentInfo()
    {
        var sut = CreateSut();
        var content = MakeContent(ContentType.Movie, 99);

        var id = await sut.QueueDownloadAsync(content, "480p");

        using var ctx = _factory.CreateDbContext();
        var download = ctx.Downloads.Find(id);
        download!.FilePath.Should().NotBeNullOrEmpty();
        download.FilePath.Should().Contain("99");
    }

    [Fact]
    public async Task QueueDownloadAsync_CanQueueMultipleDownloads()
    {
        var sut = CreateSut();

        var id1 = await sut.QueueDownloadAsync(MakeContent(ContentType.Movie, 1), "1080p");
        var id2 = await sut.QueueDownloadAsync(MakeContent(ContentType.Movie, 2), "1080p");
        var id3 = await sut.QueueDownloadAsync(MakeContent(ContentType.Episode, 1), "720p");

        id1.Should().NotBe(id2);
        id2.Should().NotBe(id3);
    }

    // ─── PauseAsync ───────────────────────────────────────────────────────────

    [Fact]
    public async Task PauseAsync_SetsStatusToPaused_WhenDownloadExists()
    {
        var sut = CreateSut();
        var id = await sut.QueueDownloadAsync(MakeContent(), "1080p");

        await sut.PauseAsync(id);

        using var ctx = _factory.CreateDbContext();
        var download = ctx.Downloads.Find(id);
        download!.Status.Should().Be(DownloadStatus.Paused);
    }

    [Fact]
    public async Task PauseAsync_DoesNotThrow_WhenDownloadNotFound()
    {
        var sut = CreateSut();

        var act = () => sut.PauseAsync(99999);
        await act.Should().NotThrowAsync();
    }

    // ─── ResumeAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task ResumeAsync_SetsStatusToQueued_WhenPaused()
    {
        var sut = CreateSut();
        var id = await sut.QueueDownloadAsync(MakeContent(), "1080p");
        await sut.PauseAsync(id);

        await sut.ResumeAsync(id);

        using var ctx = _factory.CreateDbContext();
        var download = ctx.Downloads.Find(id);
        download!.Status.Should().Be(DownloadStatus.Queued);
    }

    [Fact]
    public async Task ResumeAsync_DoesNotThrow_WhenDownloadNotFound()
    {
        var sut = CreateSut();

        var act = () => sut.ResumeAsync(99999);
        await act.Should().NotThrowAsync();
    }

    // ─── CancelAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task CancelAsync_RemovesDownload_WhenExists()
    {
        var sut = CreateSut();
        var id = await sut.QueueDownloadAsync(MakeContent(), "1080p");

        await sut.CancelAsync(id);

        using var ctx = _factory.CreateDbContext();
        var download = ctx.Downloads.Find(id);
        download.Should().BeNull("cancelled downloads should be removed from persistence");
    }

    [Fact]
    public async Task CancelAsync_DoesNotThrow_WhenDownloadNotFound()
    {
        var sut = CreateSut();

        var act = () => sut.CancelAsync(99999);
        await act.Should().NotThrowAsync();
    }

    // ─── GetDownloadsAsync ────────────────────────────────────────────────────

    [Fact]
    public async Task GetDownloadsAsync_ReturnsEmpty_WhenNoneQueued()
    {
        var sut = CreateSut();

        var result = await sut.GetDownloadsAsync();

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetDownloadsAsync_ReturnsAllQueued_AfterMultipleEnqueues()
    {
        var sut = CreateSut();
        await sut.QueueDownloadAsync(MakeContent(ContentType.Movie, 1), "1080p");
        await sut.QueueDownloadAsync(MakeContent(ContentType.Movie, 2), "720p");
        await sut.QueueDownloadAsync(MakeContent(ContentType.Episode, 3), "480p");

        var result = await sut.GetDownloadsAsync();

        result.Should().HaveCount(3);
    }

    [Fact]
    public async Task GetDownloadsAsync_ExcludesCancelled_AfterCancel()
    {
        var sut = CreateSut();
        var id1 = await sut.QueueDownloadAsync(MakeContent(ContentType.Movie, 1), "1080p");
        var id2 = await sut.QueueDownloadAsync(MakeContent(ContentType.Movie, 2), "720p");

        await sut.CancelAsync(id1);

        var result = await sut.GetDownloadsAsync();

        result.Should().HaveCount(1);
        result[0].Id.Should().Be(id2);
    }

    // ─── IHostedService lifecycle ─────────────────────────────────────────────

    [Fact]
    public async Task StartAsync_DoesNotThrow()
    {
        var sut = CreateSut();

        var act = () => sut.StartAsync(CancellationToken.None);
        await act.Should().NotThrowAsync();

        await sut.StopAsync(CancellationToken.None);
    }

    [Fact]
    public async Task StopAsync_DoesNotThrow_AfterStart()
    {
        var sut = CreateSut();
        await sut.StartAsync(CancellationToken.None);

        var act = () => sut.StopAsync(CancellationToken.None);
        await act.Should().NotThrowAsync();
    }
}
