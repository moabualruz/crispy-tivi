using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Controls;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "UI")]
public class TrackSelectorPanelTests
{
    private static (PlayerViewModel Vm, TestSubject<PlayerState> StateSubject) MakePlayerViewModel()
    {
        var playerService = Substitute.For<IPlayerService>();
        var timeshiftService = Substitute.For<ITimeshiftService>();
        var sleepTimerService = Substitute.For<ISleepTimerService>();

        var stateSubject = new TestSubject<PlayerState>();
        playerService.StateChanged.Returns(stateSubject);
        playerService.State.Returns(PlayerState.Empty);
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);
        playerService.AudioSamples.Returns(new TestSubject<float[]>());

        timeshiftService.StateChanged.Returns(new TestSubject<TimeshiftState>());
        timeshiftService.State.Returns(new TimeshiftState(
            BufferDuration: TimeSpan.Zero,
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: string.Empty,
            IsAtLiveEdge: true,
            IsBufferFull: false));

        sleepTimerService.RemainingChanged.Returns(new TestSubject<TimeSpan?>());
        sleepTimerService.Remaining.Returns((TimeSpan?)null);

        var vm = new PlayerViewModel(playerService, timeshiftService, sleepTimerService);
        return (vm, stateSubject);
    }

    [AvaloniaFact]
    public void TrackSelectorPanel_RendersWithoutException()
    {
        var (vm, _) = MakePlayerViewModel();
        var panel = new TrackSelectorPanel { DataContext = vm };
        var window = new Window { Content = panel, Width = 400, Height = 600 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void TrackSelectorPanel_HostsTrackSelectorView_WhenDataContextSet()
    {
        var (vm, _) = MakePlayerViewModel();
        var panel = new TrackSelectorPanel();
        var window = new Window { Content = panel, Width = 400, Height = 600 };
        window.Show();

        panel.DataContext = vm;

        // The TrackSelectorHost ContentControl should now contain a TrackSelectorView
        var host = panel.TrackSelectorHost;
        host.Should().NotBeNull();
        host!.Content.Should().BeOfType<TrackSelectorView>(
            "TrackSelectorPanel must embed a TrackSelectorView in its host");
        window.Close();
    }

    [AvaloniaFact]
    public void TrackSelectorPanel_CloseButton_Exists()
    {
        var (vm, _) = MakePlayerViewModel();
        var panel = new TrackSelectorPanel { DataContext = vm };
        var window = new Window { Content = panel, Width = 400, Height = 600 };
        window.Show();

        var closeButton = panel.CloseButton;
        closeButton.Should().NotBeNull("panel must have a close button");
        closeButton!.Command.Should().NotBeNull("close button must have a command bound");
        window.Close();
    }

    [AvaloniaFact]
    public void TrackSelectorPanel_CloseCommand_SetsIsTrackSelectorOpenFalse()
    {
        var (vm, _) = MakePlayerViewModel();
        vm.OpenTrackSelectorCommand.Execute(null); // opens
        vm.IsTrackSelectorOpen.Should().BeTrue();

        vm.CloseTrackSelectorCommand.Execute(null); // closes

        vm.IsTrackSelectorOpen.Should().BeFalse(
            "CloseTrackSelectorCommand must set IsTrackSelectorOpen to false");
    }

    [AvaloniaFact]
    public void TrackSelectorPanel_IsVisibleInOsd_WhenIsTrackSelectorOpenIsTrue()
    {
        var (vm, _) = MakePlayerViewModel();
        var osd = new OsdOverlay { DataContext = vm };
        var window = new Window { Content = osd, Width = 1280, Height = 720 };
        window.Show();

        // Initially closed
        var panelBefore = FindDescendant<TrackSelectorPanel>(osd);
        panelBefore.Should().NotBeNull("TrackSelectorPanel must exist in OsdOverlay visual tree");
        panelBefore!.IsVisible.Should().BeFalse("panel should be hidden when IsTrackSelectorOpen is false");

        // Open
        vm.OpenTrackSelectorCommand.Execute(null);

        panelBefore.IsVisible.Should().BeTrue("panel should be visible when IsTrackSelectorOpen is true");
        window.Close();
    }

    [AvaloniaFact]
    public void TrackSelectorPanel_SpeedSection_HiddenForLive()
    {
        var (vm, stateSubject) = MakePlayerViewModel();
        var panel = new TrackSelectorPanel();
        var window = new Window { Content = panel, Width = 400, Height = 600 };
        window.Show();
        panel.DataContext = vm;

        // Push live state
        stateSubject.OnNext(PlayerState.Empty with { IsLive = true });

        // The embedded TrackSelectorView's ViewModel should have IsLive=true
        var host = panel.TrackSelectorHost;
        host.Should().NotBeNull();
        var trackView = host!.Content as TrackSelectorView;
        trackView.Should().NotBeNull();
        var trackVm = trackView!.DataContext as TrackSelectorViewModel;
        trackVm.Should().NotBeNull();
        trackVm!.IsLive.Should().BeTrue(
            "TrackSelectorViewModel.IsLive must be true when player is in live mode, " +
            "so the speed section is hidden in the View");
        window.Close();
    }

    private static T? FindDescendant<T>(Control root) where T : Control
    {
        foreach (var child in root.GetVisualDescendants().OfType<T>())
            return child;
        return null;
    }
}
