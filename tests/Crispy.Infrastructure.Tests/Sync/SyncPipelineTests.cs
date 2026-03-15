using Crispy.Application.Sources;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Sync;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Sync;

public class SyncPipelineTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly TestEpgDbContextFactory _epgFactory;
    private readonly Crispy.Domain.Entities.Source _testSource;

    public SyncPipelineTests()
    {
        _factory = new TestDbContextFactory();
        _epgFactory = new TestEpgDbContextFactory();

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
                TvgId = $"ch{i}",
                SourceId = _testSource.Id,
            })
            .ToList();

    [Fact]
    public async Task RunAsync_ThreeChannels_AllUpserted()
    {
        var channels = MakeChannels(3);
        var parser = new FakeParser(new ParseResult { Channels = channels });
        var pipeline = new SyncPipeline(_factory, _epgFactory, NullLogger<SyncPipeline>.Instance);

        await pipeline.RunAsync(_testSource, parser, CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        ctx.Channels.Count(c => c.SourceId == _testSource.Id).Should().Be(3);
    }

    [Fact]
    public async Task RunAsync_SecondSync_IsFavoritePreserved()
    {
        var channels = MakeChannels(3);
        var pipeline = new SyncPipeline(_factory, _epgFactory, NullLogger<SyncPipeline>.Instance);

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
        var pipeline = new SyncPipeline(_factory, _epgFactory, NullLogger<SyncPipeline>.Instance);

        // First sync with 3 channels
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = allChannels }), CancellationToken.None);

        // Second sync with only first 2 (ch3 missing)
        var reduced = MakeChannels(2);
        await pipeline.RunAsync(_testSource, new FakeParser(new ParseResult { Channels = reduced }), CancellationToken.None);

        using var ctx = _factory.CreateDbContext();
        var missing = ctx.Channels.First(c => c.TvgId == "ch3" && c.SourceId == _testSource.Id);
        missing.MissedSyncCount.Should().Be(1);
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
