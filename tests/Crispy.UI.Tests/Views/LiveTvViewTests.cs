using Avalonia.Headless.XUnit;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// Smoke tests verifying that LiveTvView mounts without exceptions and that the
/// source filter bar is populated correctly under the headless Avalonia platform.
/// </summary>
[Trait("Category", "UI")]
public class LiveTvViewTests
{
    private static LiveTvViewModel BuildVm()
    {
        var channelRepo = Substitute.For<IChannelRepository>();
        channelRepo.GetBySourceAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IReadOnlyList<Channel>>([]));

        var sourceRepo = Substitute.For<ISourceRepository>();
        sourceRepo.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Source>>([]));

        return new LiveTvViewModel(channelRepo, sourceRepo, Substitute.For<INavigationService>());
    }

    [Fact]
    public void LiveTvView_Title_IsLiveTv()
    {
        BuildVm().Title.Should().Be("Live TV");
    }

    [AvaloniaFact]
    public void LiveTvView_RendersWithoutException()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<LiveTvView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }

    [AvaloniaFact]
    public void LiveTvView_SourceFilters_ContainsAllSourcesItem()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<LiveTvView>(vm);

        vm.SourceFilters.Should().ContainSingle(
            f => f.SourceId == null && f.Name == "All Sources",
            "the source filter bar must always include an 'All Sources' chip");
        window.Close();
    }

    [AvaloniaFact]
    public void LiveTvView_Channels_EmptyWhenNoSourcesConfigured()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<LiveTvView>(vm);

        vm.Channels.Should().BeEmpty();
        window.Close();
    }
}
