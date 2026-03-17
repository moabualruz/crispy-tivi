using Crispy.Application.Player.Models;
using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
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

    private static Channel MakeChannel(int id, int sourceId, string? group = null) =>
        new() { Id = id, Title = $"Ch{id}", SourceId = sourceId, GroupName = group };

    private static LiveTvViewModel MakeSut(IChannelRepository channelRepo, ISourceRepository sourceRepo) =>
        new(channelRepo, sourceRepo, Substitute.For<INavigationService>(), Substitute.For<IPlayerController>());

    // ── Constructor ────────────────────────────────────────────────────────────

    [Fact]
    public async Task Constructor_DoesNotThrow()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var act = () => MakeSut(channelRepo, sourceRepo);
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

        var sut = MakeSut(channelRepo, sourceRepo);
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

        var sut = MakeSut(channelRepo, sourceRepo);
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
        var channels = new List<Channel> { MakeChannel(1, 1), MakeChannel(2, 1) };
        channelRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));
        channelRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));

        var sut = MakeSut(channelRepo, sourceRepo);

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

        var sut = MakeSut(channelRepo, sourceRepo);
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

        var sut = MakeSut(channelRepo, sourceRepo);
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

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        sut.IsLoading.Should().BeFalse();
    }

    [Fact]
    public async Task LoadCommand_SetsIsLoadingFalse_WhenRepositoryThrows()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().ThrowsAsync(new InvalidOperationException("DB error"));

        var sut = MakeSut(channelRepo, sourceRepo);
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

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        // Switch to source2 filter.
        var source2Filter = sut.SourceFilters.First(f => f.SourceId == 2);
        sut.SelectedSourceFilter = source2Filter;
        await Task.Delay(100);

        sut.Channels.Should().HaveCount(2);
    }

    [Fact]
    public async Task LoadChannelsForFilter_AllSources_UnionsChannelsFromAllEnabledSources()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source1 = MakeSource(1, "IPTV1");
        var source2 = MakeSource(2, "IPTV2");
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([source1, source2]));
        var allChannels = new List<Channel> { MakeChannel(1, 1), MakeChannel(2, 1), MakeChannel(3, 2) };
        channelRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(allChannels));
        channelRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([MakeChannel(1, 1), MakeChannel(2, 1)]));
        channelRepo.GetBySourceAsync(2, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([MakeChannel(3, 2)]));

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        // "All Sources" is the initial selection — should return all channels via GetAllAsync.
        sut.SelectedSourceFilter!.SourceId.Should().BeNull("initial filter is All Sources");
        sut.Channels.Should().HaveCount(3, "GetAllAsync returns all 3 channels");
    }

    [Fact]
    public async Task OnSelectedSourceFilterChanged_WhenSetToNull_DoesNotReload()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        // Record call count after constructor Load completes.
        var callsBefore = sourceRepo.ReceivedCalls().Count();

        // Setting to null — OnSelectedSourceFilterChanged guard should return early (no ApplyFilterAsync).
        sut.SelectedSourceFilter = null;
        await Task.Delay(50);

        // No additional calls should have been made.
        sourceRepo.ReceivedCalls().Count().Should().Be(callsBefore,
            "setting SelectedSourceFilter to null must not trigger ApplyFilterAsync");
    }

    // ── Group filtering ────────────────────────────────────────────────────────

    [Fact]
    public async Task Groups_PopulatedFromChannels_AfterLoad()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source = MakeSource(1, "IPTV1");
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([source]));
        var channels = new List<Channel>
        {
            MakeChannel(1, 1, "Sports"),
            MakeChannel(2, 1, "News"),
            MakeChannel(3, 1, "Sports"),
            MakeChannel(4, 1, null),   // no group — excluded from chips
        };
        channelRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));
        channelRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        // "All" + 2 distinct groups in alphabetical order.
        sut.Groups.Should().Equal("All", "News", "Sports");
    }

    [Fact]
    public async Task SelectedGroup_FiltersChannels_ByGroupName()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source = MakeSource(1, "IPTV1");
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([source]));
        var channels = new List<Channel>
        {
            MakeChannel(1, 1, "Sports"),
            MakeChannel(2, 1, "News"),
            MakeChannel(3, 1, "Sports"),
        };
        channelRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));
        channelRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        sut.SelectedGroup = "Sports";

        sut.Channels.Should().HaveCount(2, "only Sports channels should be visible");
        sut.Channels.All(c => c.GroupName == "Sports").Should().BeTrue();
    }

    [Fact]
    public async Task SelectedGroup_ShowsAll_WhenAllSelected()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source = MakeSource(1, "IPTV1");
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([source]));
        var channels = new List<Channel>
        {
            MakeChannel(1, 1, "Sports"),
            MakeChannel(2, 1, "News"),
            MakeChannel(3, 1, "Sports"),
        };
        channelRepo.GetAllAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));
        channelRepo.GetBySourceAsync(1, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>(channels));

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        // First narrow to Sports, then switch back to All.
        sut.SelectedGroup = "Sports";
        sut.SelectedGroup = "All";

        sut.Channels.Should().HaveCount(3, "All group shows every channel");
    }

    [Fact]
    public async Task ApplyFilterAsync_SetsIsLoadingFalse_WhenRepositoryThrows()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();

        var source = MakeSource(1, "IPTV1");
        sourceRepo.GetAllAsync()
            .Returns(
                Task.FromResult<IReadOnlyList<Source>>([source]),  // first call (constructor Load)
                Task.FromException<IReadOnlyList<Source>>(new InvalidOperationException("network error"))); // second call (filter change)

        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sut = MakeSut(channelRepo, sourceRepo);
        await Task.Delay(100);

        // Switch to source1 filter to trigger ApplyFilterAsync which will throw on the second GetAllAsync.
        var source1Filter = sut.SourceFilters.FirstOrDefault(f => f.SourceId == 1);
        if (source1Filter is not null)
        {
            sut.SelectedSourceFilter = source1Filter;
            await Task.Delay(100);
        }

        sut.IsLoading.Should().BeFalse("IsLoading must be reset even when ApplyFilterAsync throws");
    }

    // ── SelectChannelCommand ───────────────────────────────────────────────────

    [Fact]
    public async Task SelectChannelCommand_PlaysChannel_WhenEndpointExists()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        var playerController = Substitute.For<IPlayerController>();

        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var endpoint = new StreamEndpoint { ChannelId = 7, SourceId = 1, Url = "http://stream/ch7", Priority = 0 };
        var fullChannel = new Channel { Id = 7, Title = "Sports HD", SourceId = 1, TvgLogo = "http://logo/ch7.png", IsRadio = false };
        fullChannel.StreamEndpoints.Add(endpoint);
        channelRepo.GetByIdAsync(7, Arg.Any<CancellationToken>()).Returns(Task.FromResult<Channel?>(fullChannel));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo, Substitute.For<INavigationService>(), playerController);
        await Task.Delay(50);

        var stub = MakeChannel(7, 1);
        await sut.SelectChannelCommand.ExecuteAsync(stub);

        await playerController.Received(1).PlayAsync(
            Arg.Is<PlaybackRequest>(r =>
                r.Url == "http://stream/ch7" &&
                r.ContentType == PlaybackContentType.LiveTv &&
                r.Title == "Sports HD" &&
                r.ChannelLogoUrl == "http://logo/ch7.png"));
    }

    [Fact]
    public async Task SelectChannelCommand_DoesNotPlay_WhenNoEndpoint()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        var playerController = Substitute.For<IPlayerController>();

        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        // GetByIdAsync returns channel with no endpoints.
        var fullChannel = new Channel { Id = 5, Title = "Empty Ch", SourceId = 1 };
        channelRepo.GetByIdAsync(5, Arg.Any<CancellationToken>()).Returns(Task.FromResult<Channel?>(fullChannel));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo, Substitute.For<INavigationService>(), playerController);
        await Task.Delay(50);

        var stub = MakeChannel(5, 1);
        await sut.SelectChannelCommand.ExecuteAsync(stub);

        await playerController.DidNotReceiveWithAnyArgs().PlayAsync(default!);
    }

    [Fact]
    public async Task SelectChannelCommand_UsesRadioContentType_WhenChannelIsRadio()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        var sourceRepo = Substitute.For<ISourceRepository>();
        var playerController = Substitute.For<IPlayerController>();

        sourceRepo.GetAllAsync().Returns(Task.FromResult<IReadOnlyList<Source>>([]));
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var endpoint = new StreamEndpoint { ChannelId = 9, SourceId = 1, Url = "http://stream/radio9", Priority = 0 };
        var fullChannel = new Channel { Id = 9, Title = "Radio FM", SourceId = 1, IsRadio = true };
        fullChannel.StreamEndpoints.Add(endpoint);
        channelRepo.GetByIdAsync(9, Arg.Any<CancellationToken>()).Returns(Task.FromResult<Channel?>(fullChannel));

        var sut = new LiveTvViewModel(channelRepo, sourceRepo, Substitute.For<INavigationService>(), playerController);
        await Task.Delay(50);

        var stub = MakeChannel(9, 1);
        await sut.SelectChannelCommand.ExecuteAsync(stub);

        await playerController.Received(1).PlayAsync(
            Arg.Is<PlaybackRequest>(r => r.ContentType == PlaybackContentType.Radio));
    }
}
