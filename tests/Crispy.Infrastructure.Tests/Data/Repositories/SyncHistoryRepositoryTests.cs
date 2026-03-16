using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

[Trait("Category", "Integration")]
public sealed class SyncHistoryRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory = new();
    private readonly SyncHistoryRepository _sut;

    // Source is required by the SyncHistory FK — seed one upfront.
    private int _sourceId;

    public SyncHistoryRepositoryTests()
    {
        _sut = new SyncHistoryRepository(_factory);
        _sourceId = SeedSourceAsync().GetAwaiter().GetResult();
    }

    public void Dispose() => _factory.Dispose();

    private async Task<int> SeedSourceAsync()
    {
        await using var ctx = await _factory.CreateDbContextAsync();
        var source = new Crispy.Domain.Entities.Source
        {
            Name = "Test Source",
            Url = "http://test.example.com/playlist.m3u",
        };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();
        return source.Id;
    }

    // ── BeginSyncAsync ───────────────────────────────────────────────────────

    [Fact]
    public async Task BeginSyncAsync_ReturnsPositiveId_WhenSourceExists()
    {
        var id = await _sut.BeginSyncAsync(_sourceId);

        id.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task BeginSyncAsync_PersistsRecordWithRunningStatus()
    {
        var id = await _sut.BeginSyncAsync(_sourceId);

        await using var ctx = await _factory.CreateDbContextAsync();
        var record = await ctx.SyncHistory.FindAsync(id);

        record.Should().NotBeNull();
        record!.Status.Should().Be(SyncStatus.Running);
        record.SourceId.Should().Be(_sourceId);
        record.StartedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
        record.CompletedAt.Should().BeNull();
    }

    [Fact]
    public async Task BeginSyncAsync_CreatesNewRecord_ForEachCall()
    {
        var id1 = await _sut.BeginSyncAsync(_sourceId);
        var id2 = await _sut.BeginSyncAsync(_sourceId);

        id1.Should().NotBe(id2);
    }

    // ── CompleteSyncAsync ────────────────────────────────────────────────────

    [Fact]
    public async Task CompleteSyncAsync_UpdatesRecord_WithCompletedStatus()
    {
        var id = await _sut.BeginSyncAsync(_sourceId);

        await _sut.CompleteSyncAsync(
            syncHistoryId: id,
            status: SyncStatus.Completed,
            channelCount: 100,
            vodCount: 50,
            epgCount: 200,
            durationMs: 1234);

        await using var ctx = await _factory.CreateDbContextAsync();
        var record = await ctx.SyncHistory.FindAsync(id);

        record!.Status.Should().Be(SyncStatus.Completed);
        record.ChannelCount.Should().Be(100);
        record.VodCount.Should().Be(50);
        record.EpgCount.Should().Be(200);
        record.DurationMs.Should().Be(1234);
        record.CompletedAt.Should().NotBeNull();
        record.ErrorMessage.Should().BeNull();
    }

    [Fact]
    public async Task CompleteSyncAsync_RecordsErrorMessage_WhenStatusIsFailed()
    {
        var id = await _sut.BeginSyncAsync(_sourceId);

        await _sut.CompleteSyncAsync(
            syncHistoryId: id,
            status: SyncStatus.Failed,
            channelCount: 0,
            vodCount: 0,
            epgCount: 0,
            durationMs: 500,
            errorMessage: "Connection timeout");

        await using var ctx = await _factory.CreateDbContextAsync();
        var record = await ctx.SyncHistory.FindAsync(id);

        record!.Status.Should().Be(SyncStatus.Failed);
        record.ErrorMessage.Should().Be("Connection timeout");
    }

    [Fact]
    public async Task CompleteSyncAsync_DoesNotThrow_WhenIdDoesNotExist()
    {
        var act = async () => await _sut.CompleteSyncAsync(
            syncHistoryId: 9999,
            status: SyncStatus.Completed,
            channelCount: 0,
            vodCount: 0,
            epgCount: 0,
            durationMs: 0);

        await act.Should().NotThrowAsync();
    }

    // ── GetRecentAsync ───────────────────────────────────────────────────────

    [Fact]
    public async Task GetRecentAsync_ReturnsEmpty_WhenNoRecordsExistForSource()
    {
        var result = await _sut.GetRecentAsync(_sourceId);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetRecentAsync_ReturnsRecordsOrderedByStartedAtDescending()
    {
        var id1 = await _sut.BeginSyncAsync(_sourceId);
        // Force distinct timestamps by touching the record directly
        await using (var ctx = await _factory.CreateDbContextAsync())
        {
            var r = await ctx.SyncHistory.FindAsync(id1);
            r!.StartedAt = DateTime.UtcNow.AddMinutes(-5);
            await ctx.SaveChangesAsync();
        }

        var id2 = await _sut.BeginSyncAsync(_sourceId);
        await using (var ctx = await _factory.CreateDbContextAsync())
        {
            var r = await ctx.SyncHistory.FindAsync(id2);
            r!.StartedAt = DateTime.UtcNow;
            await ctx.SaveChangesAsync();
        }

        var result = await _sut.GetRecentAsync(_sourceId);

        result.Should().HaveCount(2);
        result[0].Id.Should().Be(id2, "most recent record should come first");
        result[1].Id.Should().Be(id1);
    }

    [Fact]
    public async Task GetRecentAsync_RespectsCountLimit()
    {
        for (int i = 0; i < 5; i++)
            await _sut.BeginSyncAsync(_sourceId);

        var result = await _sut.GetRecentAsync(_sourceId, count: 3);

        result.Should().HaveCount(3);
    }

    [Fact]
    public async Task GetRecentAsync_ReturnsOnlyRecordsForRequestedSource()
    {
        var otherId = await SeedSourceAsync();

        await _sut.BeginSyncAsync(_sourceId);
        await _sut.BeginSyncAsync(otherId);

        var result = await _sut.GetRecentAsync(_sourceId);

        result.Should().AllSatisfy(r => r.SourceId.Should().Be(_sourceId));
    }

    [Fact]
    public async Task GetRecentAsync_DefaultsToTenRecords()
    {
        for (int i = 0; i < 15; i++)
            await _sut.BeginSyncAsync(_sourceId);

        var result = await _sut.GetRecentAsync(_sourceId);

        result.Should().HaveCount(10);
    }
}
