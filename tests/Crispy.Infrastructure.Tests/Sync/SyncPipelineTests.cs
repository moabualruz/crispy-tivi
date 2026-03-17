using Crispy.Application.Sources;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using Crispy.Infrastructure.Sync;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using NSubstitute;

using Xunit;

namespace Crispy.Infrastructure.Tests.Sync;

[Trait("Category", "Unit")]
public class SyncPipelineTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly TestEpgDbContextFactory _epgFactory;
    private readonly IMovieRepository _movieRepo;
    private readonly ISeriesRepository _seriesRepo;
    private readonly Crispy.Domain.Entities.Source _testSource;

    public SyncPipelineTests()
    {
        _factory = new TestDbContextFactory();
        _epgFactory = new TestEpgDbContextFactory();
        _movieRepo = Substitute.For<IMovieRepository>();
        _seriesRepo = Substitute.For<ISeriesRepository>();

        using var ctx = _factory.CreateDbContext();
        var profile = new Profile { Name = "Test" };
        ctx.Profiles.Add(profile);
        ctx.SaveChanges();

        var source = new Source
        {
            Name = "TestSource",
            Url = "http://test.com",
            ProfileId = profile.Id,
            SourceType = SourceType.M3U,
        };
        ctx.Sources.Add(source);
        ctx.SaveChanges();
        _testSource = source;
    }

    private List<Crispy.Domain.Entities.Channel> MakeChannels(int count) =>
        Enumerable.Range(1, count)
            .Select(i => new Crispy.Domain.Entities.Channel
            {
                Title = $"Channel {i}",
                ExternalId = $"ch{i}",
                TvgId = $"ch{i}",
                SourceId = _testSource.Id,
            })
            .ToList();

    [Fact]
    public async Task RunAsync_ThreeChannels_AllUpserted()
    {
        var channels = MakeChannels(3);
        var parser = new FakeParser(new ParseResult { Channels = channels });
        var pipeline = new SyncPipeline(_factory, _epgFactory, _movieRepo, _seriesRepo, NullLogger<SyncPipeline>.Instance);

        await pipeline.RunAsync(_testSource, parser, CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        ctx.Channels.Count(c => c.SourceId == _testSource.Id).Should().Be(3);
    }

    [Fact]
    public async Task RunAsync_SecondSync_IsFavoritePreserved()
    {
        var channels = MakeChannels(3);
        var pipeline = new SyncPipeline(_factory, _epgFactory, _movieRepo, _seriesRepo, NullLogger<SyncPipeline>.Instance);

        // First sync
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = channels }), CancellationToken.None);

        // Mark channel 1 as favorite
        using (var ctx = _factory.CreateDbContext())
        {
            var ch = ctx.Channels.First(c => c.TvgId == "ch1" && c.SourceId == _testSource.Id);
            ch.IsFavorite = true;
            ctx.SaveChanges();
        }

        // Second sync — same channels
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = channels }), CancellationToken.None);

        using var ctx2 = _factory.CreateDbContext();
        var favCh = ctx2.Channels.First(c => c.TvgId == "ch1" && c.SourceId == _testSource.Id);
        favCh.IsFavorite.Should().BeTrue("IsFavorite must be preserved across sync upsert");
    }

    [Fact]
    public async Task RunAsync_MissingChannel_MissedSyncCountIncremented()
    {
        var allChannels = MakeChannels(3);
        var pipeline = new SyncPipeline(_factory, _epgFactory, _movieRepo, _seriesRepo, NullLogger<SyncPipeline>.Instance);

        // First sync with 3 channels
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = allChannels }), CancellationToken.None);

        // Second sync with only first 2 (ch3 missing)
        var reduced = MakeChannels(2);
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = reduced }), CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        var missing = ctx.Channels.First(c => c.TvgId == "ch3" && c.SourceId == _testSource.Id);
        missing.MissedSyncCount.Should().Be(1);
    }

    [Fact]
    public async Task RunAsync_EmptyParseResult_NoChannelsInserted()
    {
        var pipeline = new SyncPipeline(_factory, _epgFactory, _movieRepo, _seriesRepo, NullLogger<SyncPipeline>.Instance);

        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult()), CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        ctx.Channels.Count(c => c.SourceId == _testSource.Id).Should().Be(0,
            "empty parse result must not insert any channels");
    }

    [Fact]
    public async Task RunAsync_ChannelWithExternalId_UpsertedById()
    {
        // Channel with ExternalId — upsert should match by ExternalId
        var ch = new Crispy.Domain.Entities.Channel
        {
            Title = "External ID Channel",
            ExternalId = "ext-123",
            TvgId = null,
            SourceId = _testSource.Id,
        };
        var pipeline = new SyncPipeline(_factory, _epgFactory, _movieRepo, _seriesRepo, NullLogger<SyncPipeline>.Instance);

        // Two syncs with same ExternalId — should result in exactly one DB row
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = [ch] }), CancellationToken.None);
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = [ch] }), CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        ctx.Channels.Count(c => c.SourceId == _testSource.Id && c.ExternalId == "ext-123")
            .Should().Be(1, "same ExternalId channel must upsert, not duplicate");
    }

    [Fact]
    public async Task RunAsync_ReappearedChannel_MissedSyncCountReset()
    {
        var channels = MakeChannels(3);
        var pipeline = new SyncPipeline(_factory, _epgFactory, _movieRepo, _seriesRepo, NullLogger<SyncPipeline>.Instance);

        // Sync 1: all 3 present
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = channels }), CancellationToken.None);

        // Sync 2: ch3 absent → MissedSyncCount = 1
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = MakeChannels(2) }), CancellationToken.None);

        // Sync 3: all 3 back → MissedSyncCount for ch3 reset to 0
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = channels }), CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        var ch3 = ctx.Channels.First(c => c.TvgId == "ch3" && c.SourceId == _testSource.Id);
        ch3.MissedSyncCount.Should().Be(0, "MissedSyncCount must reset to 0 when channel reappears");
    }

    [Fact]
    public async Task RunAsync_LargeChannelList_AllInserted()
    {
        // BatchSize is 500 — verify batching works by inserting > 500 channels
        var channels = MakeChannels(550);
        var pipeline = new SyncPipeline(_factory, _epgFactory, _movieRepo, _seriesRepo, NullLogger<SyncPipeline>.Instance);

        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = channels }), CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        ctx.Channels.Count(c => c.SourceId == _testSource.Id).Should().Be(550,
            "all 550 channels across multiple batches must be inserted");
    }

    public void Dispose()
    {
        _factory.Dispose();
        _epgFactory.Dispose();
    }

    private sealed class FakeParser : ISourceParser
    {
        private readonly ParseResult _result;
        public FakeParser(ParseResult result) => _result = result;
        public Task<ParseResult> ParseAsync(Crispy.Domain.Entities.Source source, CancellationToken ct = default) =>
            Task.FromResult(_result);
    }
}
