using Crispy.Application.Player;
using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.Infrastructure.Player;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class StreamHealthRepositoryTests
{
    // ─── Fake ────────────────────────────────────────────────────────────────

    private sealed class FakeChannelRepository : IChannelRepository
    {
        private readonly Dictionary<int, Channel> _channels = new();

        public void Add(Channel channel) => _channels[channel.Id] = channel;

        public Task<Channel?> GetByIdAsync(int id, CancellationToken ct = default)
            => Task.FromResult(_channels.GetValueOrDefault(id));

        public Task<IReadOnlyList<Channel>> GetBySourceAsync(int sourceId, CancellationToken ct = default)
            => Task.FromResult<IReadOnlyList<Channel>>([]);

        public Task<int> UpsertRangeAsync(IEnumerable<Channel> channels, CancellationToken ct = default)
            => Task.FromResult(0);

        public Task IncrementMissedSyncAsync(int sourceId, IEnumerable<string> presentTvgIds, CancellationToken ct = default)
            => Task.CompletedTask;

        public Task SoftRemoveExpiredAsync(int sourceId, int threshold, CancellationToken ct = default)
            => Task.CompletedTask;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static StreamHealthRepository CreateSut(FakeChannelRepository? repo = null)
        => new(repo ?? new FakeChannelRepository());

    // ─── RecordStallAsync ─────────────────────────────────────────────────────

    [Fact]
    public async Task RecordStallAsync_CreatesNewRecord_WhenHashUnknown()
    {
        var sut = CreateSut();

        await sut.RecordStallAsync("hash-1");

        // After one stall the score should be < 1.0 (degraded from healthy baseline)
        var score = await sut.GetHealthScoreAsync("hash-1");
        score.Should().BeLessThan(1.0f);
    }

    [Fact]
    public async Task RecordStallAsync_AccumulatesStalls_OnSameHash()
    {
        var sut = CreateSut();
        const string hash = "stall-hash";

        await sut.RecordStallAsync(hash);
        var scoreAfterOne = await sut.GetHealthScoreAsync(hash);

        await sut.RecordStallAsync(hash);
        await sut.RecordStallAsync(hash);
        await sut.RecordStallAsync(hash);
        await sut.RecordStallAsync(hash);
        var scoreAfterFive = await sut.GetHealthScoreAsync(hash);

        scoreAfterFive.Should().BeLessThan(scoreAfterOne);
    }

    [Fact]
    public async Task RecordStallAsync_IsolatesHashes_DoesNotBleedToOtherHash()
    {
        var sut = CreateSut();

        await sut.RecordStallAsync("a");
        var scoreB = await sut.GetHealthScoreAsync("b");

        scoreB.Should().Be(1.0f, "b has no data — should be assumed healthy");
    }

    // ─── RecordBufferDurationAsync ────────────────────────────────────────────

    [Fact]
    public async Task RecordBufferDurationAsync_ReducesScore_WhenHighBuffer()
    {
        var sut = CreateSut();
        const string hash = "buf-hash";

        // 9000ms buffer (near the 10000ms cap)
        await sut.RecordBufferDurationAsync(hash, 9000);

        var score = await sut.GetHealthScoreAsync(hash);
        score.Should().BeLessThan(1.0f);
    }

    [Fact]
    public async Task RecordBufferDurationAsync_AccumulatesSamples_AveragingDuration()
    {
        var sut = CreateSut();
        const string hash = "buf-avg";

        await sut.RecordBufferDurationAsync(hash, 1000);
        var scoreAfterOne = await sut.GetHealthScoreAsync(hash);

        await sut.RecordBufferDurationAsync(hash, 9000);
        var scoreAfterTwo = await sut.GetHealthScoreAsync(hash);

        // Average buffer goes up → score should drop further
        scoreAfterTwo.Should().BeLessThanOrEqualTo(scoreAfterOne);
    }

    // ─── RecordTtffAsync ──────────────────────────────────────────────────────

    [Fact]
    public async Task RecordTtffAsync_ReducesScore_WhenHighTtff()
    {
        var sut = CreateSut();
        const string hash = "ttff-hash";

        await sut.RecordTtffAsync(hash, 9500);

        var score = await sut.GetHealthScoreAsync(hash);
        score.Should().BeLessThan(1.0f);
    }

    [Fact]
    public async Task RecordTtffAsync_KeepsRollingAverage_AcrossTwoSamples()
    {
        var sut = CreateSut();
        const string hash = "ttff-avg";

        await sut.RecordTtffAsync(hash, 2000);
        await sut.RecordTtffAsync(hash, 4000);
        // Rolling average = (2000 + 4000) / 2 = 3000

        var score = await sut.GetHealthScoreAsync(hash);
        // 3000ms TTFF → ttffFactor = 0.3 → penalty 0.3*0.2 = 0.06 → rawScore ~0.94
        score.Should().BeGreaterThan(0.85f).And.BeLessThan(1.0f);
    }

    // ─── GetHealthScoreAsync ──────────────────────────────────────────────────

    [Fact]
    public async Task GetHealthScoreAsync_ReturnsOne_WhenNoDataExists()
    {
        var sut = CreateSut();

        var score = await sut.GetHealthScoreAsync("unknown-hash");

        score.Should().Be(1.0f);
    }

    [Fact]
    public async Task GetHealthScoreAsync_ReturnsValueInRange_AfterRecording()
    {
        var sut = CreateSut();
        const string hash = "range-test";

        await sut.RecordStallAsync(hash);
        await sut.RecordBufferDurationAsync(hash, 5000);
        await sut.RecordTtffAsync(hash, 3000);

        var score = await sut.GetHealthScoreAsync(hash);
        score.Should().BeGreaterThanOrEqualTo(0.0f).And.BeLessThanOrEqualTo(1.0f);
    }

    [Fact]
    public async Task GetHealthScoreAsync_VerifiesFormula_TenStallsMaxPenalty()
    {
        var sut = CreateSut();
        const string hash = "formula-stall";

        // 10 stalls → stallFactor clamped to 1.0 → penalty 0.5 → rawScore = 0.5
        // With near-zero decay (just recorded), score ≈ 0.5 + (0.5 - 0.5) * ~1 = 0.5
        for (var i = 0; i < 10; i++)
            await sut.RecordStallAsync(hash);

        var score = await sut.GetHealthScoreAsync(hash);
        score.Should().BeApproximately(0.5f, precision: 0.05f);
    }

    // ─── GetRankedAlternativesAsync ───────────────────────────────────────────

    [Fact]
    public async Task GetRankedAlternativesAsync_ReturnsEmpty_WhenChannelNotFound()
    {
        var sut = CreateSut();

        var result = await sut.GetRankedAlternativesAsync(channelId: 999, excludeSourceId: 1);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetRankedAlternativesAsync_ReturnsEmpty_WhenChannelHasNoEndpoints()
    {
        var repo = new FakeChannelRepository();
        repo.Add(new Channel { Id = 1, Title = "Test", SourceId = 1 });
        var sut = CreateSut(repo);

        var result = await sut.GetRankedAlternativesAsync(channelId: 1, excludeSourceId: 1);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetRankedAlternativesAsync_ExcludesEndpointsFromGivenSource()
    {
        var repo = new FakeChannelRepository();
        var channel = new Channel
        {
            Id = 1,
            Title = "Test",
            SourceId = 1,
            StreamEndpoints = [
                new StreamEndpoint { Id = 10, ChannelId = 1, SourceId = 1, Url = "http://src1.stream" },
                new StreamEndpoint { Id = 11, ChannelId = 1, SourceId = 2, Url = "http://src2.stream" },
            ],
        };
        repo.Add(channel);
        var sut = CreateSut(repo);

        var result = await sut.GetRankedAlternativesAsync(channelId: 1, excludeSourceId: 1);

        result.Should().HaveCount(1);
        result[0].SourceId.Should().Be(2);
    }

    [Fact]
    public async Task GetRankedAlternativesAsync_RanksHigherHealthFirst()
    {
        var repo = new FakeChannelRepository();
        var channel = new Channel
        {
            Id = 1,
            Title = "Test",
            SourceId = 99,
            StreamEndpoints = [
                new StreamEndpoint { Id = 10, ChannelId = 1, SourceId = 2, Url = "http://bad.stream" },
                new StreamEndpoint { Id = 11, ChannelId = 1, SourceId = 3, Url = "http://good.stream" },
            ],
        };
        repo.Add(channel);
        var sut = CreateSut(repo);

        // Degrade the "bad" endpoint
        var badHash = StreamUrlHash.Compute("http://bad.stream");
        for (var i = 0; i < 10; i++)
            await sut.RecordStallAsync(badHash);

        var result = await sut.GetRankedAlternativesAsync(channelId: 1, excludeSourceId: 99);

        result.Should().HaveCount(2);
        result[0].Url.Should().Be("http://good.stream", "healthy stream should rank first");
        result[0].FailoverScore.Should().BeGreaterThan(result[1].FailoverScore);
    }
}
