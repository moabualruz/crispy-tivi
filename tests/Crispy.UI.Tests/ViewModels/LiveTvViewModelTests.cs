using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;
using NSubstitute.ExceptionExtensions;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class LiveTvViewModelTests
{
    private static Source MakeSource(int id, string name, bool enabled = true) =>
        new() { Id = id, Name = name, Url = "http://test", IsEnabled = enabled };

    private static Channel MakeChannel(int id, int sourceId) =>
        new() { Id = id, Title = $"Ch{id}", SourceId = sourceId };

    // ── Constructor ────────────────────────────────────────────────────────────

    [Fact]
    public async Task Constructor_DoesNotThrow()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var act = () => new LiveTvViewModel(channelRepo, sourceRepo);
        act.Should().NotThrow();

        // Allow fire-and-forget Load to complete.
        await Task.Delay(50);
    }

    [Fact]
    public void Title_IsLiveTv()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);
        sut.Title.Should().Be("Live TV");
    }

    [Fact]
    public void Channels_DefaultsToEmpty()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);
        sut.Channels.Should().NotBeNull();
    }

    // ── LoadCommand populates channels ─────────────────────────────────────────

    [Fact]
    public async Task LoadCommand_PopulatesChannels_WhenSourceHasChannels()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source = MakeSource(1, "IPTV1");
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([source]));
        channelRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([MakeChannel(1, 1), MakeChannel(2, 1)]));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);

        // Wait for the fire-and-forget Load triggered in constructor.
        await Task.Delay(100);

        sut.Channels.Should().HaveCount(2);
    }

    [Fact]
    public async Task LoadCommand_BuildsSourceFilters_IncludingAllSources()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source = MakeSource(1, "IPTV1");
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([source]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);
        await Task.Delay(100);

        // "All Sources" chip + one per enabled source.
        sut.SourceFilters.Should().HaveCount(2);
        sut.SourceFilters[0].SourceId.Should().BeNull();
        sut.SourceFilters[0].Name.Should().Be("All Sources");
    }

    [Fact]
    public async Task LoadCommand_ExcludesDisabledSources()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>(
            [
                MakeSource(1, "Enabled", enabled: true),
                MakeSource(2, "Disabled", enabled: false),
            ]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);
        await Task.Delay(100);

        // "All Sources" + only 1 enabled source.
        sut.SourceFilters.Should().HaveCount(2);
    }

    [Fact]
    public async Task LoadCommand_SetsIsLoadingFalse_AfterCompletion()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);
        await Task.Delay(100);

        sut.IsLoading.Should().BeFalse();
    }

    [Fact]
    public async Task LoadCommand_SetsIsLoadingFalse_WhenRepositoryThrows()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().ThrowsAsync(new InvalidOperationException("DB error"));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);
        await Task.Delay(100);

        sut.IsLoading.Should().BeFalse();
    }

    // ── Filter selection ───────────────────────────────────────────────────────

    [Fact]
    public async Task SelectedSourceFilter_WhenChanged_LoadsChannelsForThatSource()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source1 = MakeSource(1, "IPTV1");
        var source2 = MakeSource(2, "IPTV2");
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([source1, source2]));
        channelRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([MakeChannel(10, 1)]));
        channelRepo.GetBySourceAsync(2, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([MakeChannel(20, 2), MakeChannel(21, 2)]));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo);
        await Task.Delay(100);

        // Switch to source2 filter.
        var source2Filter = sut.SourceFilters.First(f => f.SourceId == 2);
        sut.SelectedSourceFilter = source2Filter;
        await Task.Delay(100);

        sut.Channels.Should().HaveCount(2);
    }
}
