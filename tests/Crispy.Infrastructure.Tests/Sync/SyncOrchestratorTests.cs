using Crispy.Application.Sources;
using Crispy.Application.Sync;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using Crispy.Infrastructure.Sync;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;

using NSubstitute;

using Xunit;

namespace Crispy.Infrastructure.Tests.Sync;

[Trait("Category", "Unit")]
public class SyncOrchestratorTests : IDisposable
{
    // ─── Fakes ────────────────────────────────────────────────────────────────

    private sealed class FakeSourceRepository : ISourceRepository
    {
        private readonly Dictionary<int, Source?> _byId = [];
        private List<Source> _all = [];
        public bool ThrowOnGetAll { get; set; }

        public void SetById(int id, Source? source) => _byId[id] = source;
        public void SetAll(List<Source> sources) => _all = sources;

        public Task<Source?> GetByIdAsync(int id) =>
            Task.FromResult(_byId.TryGetValue(id, out var s) ? s : null);

        public Task<IReadOnlyList<Source>> GetAllAsync()
        {
            if (ThrowOnGetAll)
                throw new InvalidOperationException("DB error");
            return Task.FromResult<IReadOnlyList<Source>>(_all);
        }

        public Task<IReadOnlyList<Source>> GetByProfileAsync(int profileId) =>
            Task.FromResult<IReadOnlyList<Source>>([]);

        public Task<Source> CreateAsync(Source source) => Task.FromResult(source);
        public Task UpdateAsync(Source source) => Task.CompletedTask;
        public Task DeleteAsync(int id) => Task.CompletedTask;
    }

    private sealed class FakeParser : ISourceParser
    {
        private readonly ParseResult _result;
        public int CallCount { get; private set; }

        public FakeParser(ParseResult? result = null) =>
            _result = result ?? new ParseResult { Channels = [] };

        public Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default)
        {
            CallCount++;
            return Task.FromResult(_result);
        }
    }

    private sealed class ThrowingParser : ISourceParser
    {
        public Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default) =>
            throw new InvalidOperationException("Parser failure");
    }

    private sealed class CancellingParser : ISourceParser
    {
        public Task<ParseResult> ParseAsync(Source source, CancellationToken ct = default)
        {
            ct.ThrowIfCancellationRequested();
            return Task.FromResult(new ParseResult { Channels = [] });
        }
    }

    // ─── Setup ────────────────────────────────────────────────────────────────

    private readonly TestDbContextFactory _dbFactory;
    private readonly TestEpgDbContextFactory _epgFactory;
    private readonly FakeSourceRepository _sourceRepo = new();
    private readonly SyncScheduler _scheduler;

    private Profile _profile = null!;
    private Source _m3uSource = null!;

    public SyncOrchestratorTests()
    {
        _dbFactory = new TestDbContextFactory();
        _epgFactory = new TestEpgDbContextFactory();

        // Very long interval — timer will never fire during tests
        _scheduler = new SyncScheduler(
            _ => Task.CompletedTask,
            NullLogger<SyncScheduler>.Instance,
            interval: TimeSpan.FromDays(1));

        SeedDatabase();
    }

    private void SeedDatabase()
    {
        using var ctx = _dbFactory.CreateDbContext();

        _profile = new Profile { Name = "Test" };
        ctx.Profiles.Add(_profile);
        ctx.SaveChanges();

        _m3uSource = new Source
        {
            Name = "M3U Source",
            Url = "http://test.m3u",
            ProfileId = _profile.Id,
            SourceType = SourceType.M3U,
            IsEnabled = true,
        };
        ctx.Sources.Add(_m3uSource);
        ctx.SaveChanges();
    }

    private SyncOrchestrator CreateSut(IReadOnlyDictionary<SourceType, ISourceParser>? parsers = null)
    {
        parsers ??= new Dictionary<SourceType, ISourceParser>
        {
            [SourceType.M3U] = new FakeParser(),
        };

        return new SyncOrchestrator(
            _sourceRepo,
            parsers,
            new SyncPipeline(_dbFactory, _epgFactory, Substitute.For<IMovieRepository>(), Substitute.For<ISeriesRepository>(), NullLogger<SyncPipeline>.Instance),
            new ChannelDeduplicator(_dbFactory),
            _scheduler,
            NullLogger<SyncOrchestrator>.Instance);
    }

    public void Dispose()
    {
        _scheduler.DisposeAsync().GetAwaiter().GetResult();
        _dbFactory.Dispose();
        _epgFactory.Dispose();
    }

    // ─── SyncSourceAsync ──────────────────────────────────────────────────────

    [Fact]
    public async Task SyncSourceAsync_CallsParser_ForRegisteredSourceType()
    {
        var parser = new FakeParser();
        _sourceRepo.SetById(_m3uSource.Id, _m3uSource);

        var sut = CreateSut(new Dictionary<SourceType, ISourceParser>
        {
            [SourceType.M3U] = parser,
        });

        await sut.SyncSourceAsync(_m3uSource.Id);

        parser.CallCount.Should().Be(1);
    }

    [Fact]
    public async Task SyncSourceAsync_DoesNotThrow_WhenSourceNotFound()
    {
        // 999 not registered — GetByIdAsync returns null
        var sut = CreateSut();

        var act = () => sut.SyncSourceAsync(999);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task SyncSourceAsync_DoesNotThrow_WhenNoParserRegistered()
    {
        var source = new Source
        {
            Name = "Xtream",
            Url = "http://xtream.test",
            ProfileId = _profile.Id,
            SourceType = SourceType.XtreamCodes,
            IsEnabled = true,
        };
        _sourceRepo.SetById(source.Id, source);

        // Only M3U parser registered — XtreamCodes has no parser
        var sut = CreateSut();

        var act = () => sut.SyncSourceAsync(source.Id);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task SyncSourceAsync_DoesNotThrow_WhenParserThrows()
    {
        _sourceRepo.SetById(_m3uSource.Id, _m3uSource);

        var sut = CreateSut(new Dictionary<SourceType, ISourceParser>
        {
            [SourceType.M3U] = new ThrowingParser(),
        });

        var act = () => sut.SyncSourceAsync(_m3uSource.Id);
        await act.Should().NotThrowAsync("exceptions in individual source sync must be swallowed");
    }

    // ─── SyncAllAsync ─────────────────────────────────────────────────────────

    [Fact]
    public async Task SyncAllAsync_OnlyProcessesEnabledSources()
    {
        var disabledSource = new Source
        {
            Name = "Disabled",
            Url = "http://disabled.test",
            ProfileId = _profile.Id,
            SourceType = SourceType.M3U,
            IsEnabled = false,
        };

        _sourceRepo.SetAll([_m3uSource, disabledSource]);
        _sourceRepo.SetById(_m3uSource.Id, _m3uSource);

        var parser = new FakeParser();
        var sut = CreateSut(new Dictionary<SourceType, ISourceParser>
        {
            [SourceType.M3U] = parser,
        });

        await sut.SyncAllAsync();

        parser.CallCount.Should().Be(1, "only the enabled source should be synced");
    }

    [Fact]
    public async Task SyncAllAsync_DoesNotThrow_WhenSourceListIsEmpty()
    {
        _sourceRepo.SetAll([]);

        var sut = CreateSut();

        var act = () => sut.SyncAllAsync();
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task SyncAllAsync_ContinuesSyncing_WhenOneSourceFails()
    {
        var source2 = new Source
        {
            Name = "Source2",
            Url = "http://source2.test",
            ProfileId = _profile.Id,
            SourceType = SourceType.XtreamCodes,
            IsEnabled = true,
        };

        _sourceRepo.SetAll([_m3uSource, source2]);
        _sourceRepo.SetById(_m3uSource.Id, _m3uSource);
        _sourceRepo.SetById(source2.Id, source2);

        var goodParser = new FakeParser();
        var sut = CreateSut(new Dictionary<SourceType, ISourceParser>
        {
            [SourceType.M3U] = goodParser,
            [SourceType.XtreamCodes] = new ThrowingParser(),
        });

        var act = () => sut.SyncAllAsync();
        await act.Should().NotThrowAsync();

        goodParser.CallCount.Should().Be(1, "good source should still complete");
    }

    // ─── StopAsync ────────────────────────────────────────────────────────────

    [Fact]
    public async Task StopAsync_DoesNotThrow_WhenNotStarted()
    {
        var sut = CreateSut();
        var act = () => sut.StopAsync();
        await act.Should().NotThrowAsync();
    }

    // ─── IHostedService ───────────────────────────────────────────────────────

    [Fact]
    public async Task IHostedService_StartAsync_DoesNotThrow()
    {
        _sourceRepo.SetAll([]);

        IHostedService sut = CreateSut();

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        var act = () => sut.StartAsync(cts.Token);
        await act.Should().NotThrowAsync();

        await sut.StopAsync(CancellationToken.None);
    }

    [Fact]
    public async Task IHostedService_StopAsync_DoesNotThrow_WhenNotStarted()
    {
        IHostedService sut = CreateSut();

        var act = () => sut.StopAsync(CancellationToken.None);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task IHostedService_StartThenStop_CompletesCleanly()
    {
        _sourceRepo.SetAll([]);

        IHostedService sut = CreateSut();

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        await sut.StartAsync(cts.Token);

        // Give the fire-and-forget task a moment to run
        await Task.Delay(50);

        var act = () => sut.StopAsync(CancellationToken.None);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task IHostedService_StartAsync_ExceptionInGetAllAsync_HitsExceptionCatchBranch()
    {
        // Source repo throws InvalidOperationException on GetAllAsync, so SyncAllAsync
        // propagates it into the fire-and-forget catch(Exception) branch.
        _sourceRepo.ThrowOnGetAll = true;

        IHostedService sut = CreateSut();

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        var act = () => sut.StartAsync(cts.Token);
        await act.Should().NotThrowAsync();

        // Allow the Task.Run body to execute and hit catch(Exception)
        await Task.Delay(200);
        await sut.StopAsync(CancellationToken.None);
    }

    [Fact]
    public async Task IHostedService_StartAsync_CancelledAfterStart_HitsOceCatchBranch()
    {
        // Cancel immediately after StartAsync returns — the fire-and-forget task
        // calls SyncAllAsync with a token that becomes cancelled during GetAllAsync,
        // exercising the catch(OperationCanceledException) branch.
        _sourceRepo.SetAll([]);

        IHostedService sut = CreateSut();

        using var cts = new CancellationTokenSource();
        await sut.StartAsync(cts.Token);

        // Cancel immediately so the in-flight SyncAllAsync picks up cancellation
        await cts.CancelAsync();

        await Task.Delay(200);
    }

    // ─── ISyncOrchestrator.StartAsync (public method, not IHostedService) ─────

    [Fact]
    public async Task ISyncOrchestrator_StartAsync_SyncsAllSources()
    {
        _sourceRepo.SetAll([_m3uSource]);
        _sourceRepo.SetById(_m3uSource.Id, _m3uSource);

        var parser = new FakeParser();
        var sut = CreateSut(new Dictionary<SourceType, ISourceParser>
        {
            [SourceType.M3U] = parser,
        });

        await sut.StartAsync(CancellationToken.None);

        parser.CallCount.Should().Be(1, "StartAsync should sync all enabled sources");
    }

    [Fact]
    public async Task ISyncOrchestrator_StartAsync_DoesNotThrow_WhenNoSources()
    {
        _sourceRepo.SetAll([]);

        var sut = CreateSut();

        var act = () => sut.StartAsync(CancellationToken.None);
        await act.Should().NotThrowAsync();
    }

    // ─── StopAsync when _startupCts is not null ───────────────────────────────

    [Fact]
    public async Task StopAsync_CancelsStartupCts_WhenStartedViaIHostedService()
    {
        _sourceRepo.SetAll([]);

        IHostedService hosted = CreateSut();

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        await hosted.StartAsync(cts.Token);

        // Give fire-and-forget a moment, then stop — exercises _startupCts.CancelAsync()
        await Task.Delay(50);

        var orchestrator = (ISyncOrchestrator)hosted;
        var act = () => orchestrator.StopAsync();
        await act.Should().NotThrowAsync();
    }

    // ─── SyncSourceAsync: OperationCanceledException propagates (not swallowed) ─

    [Fact]
    public async Task SyncSourceAsync_PropagatesOperationCanceledException()
    {
        // The catch filter `when ex is not OperationCanceledException` lets OCE propagate.
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        _sourceRepo.SetById(_m3uSource.Id, _m3uSource);

        var sut = CreateSut(new Dictionary<SourceType, ISourceParser>
        {
            [SourceType.M3U] = new CancellingParser(),
        });

        var act = () => sut.SyncSourceAsync(_m3uSource.Id, cts.Token);
        await act.Should().ThrowAsync<OperationCanceledException>(
            "OperationCanceledException must NOT be swallowed by the catch filter");
    }
}
