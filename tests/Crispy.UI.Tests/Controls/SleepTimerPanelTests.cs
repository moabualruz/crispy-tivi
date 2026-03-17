using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Controls;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "UI")]
public class SleepTimerPanelTests
{
    private static (PlayerViewModel Vm, ISleepTimerService SleepSvc) MakePlayerViewModel()
    {
        var playerService = Substitute.For<IPlayerService>();
        var timeshiftService = Substitute.For<ITimeshiftService>();
        var sleepTimerService = Substitute.For<ISleepTimerService>();

        var stateSubject = new TestSubject<PlayerState>();
        playerService.StateChanged.Returns(stateSubject);
        playerService.State.Returns(PlayerState.Empty);
        playerService.AudioTracks.Returns(new List<TrackInfo>().AsReadOnly());
        playerService.SubtitleTracks.Returns(new List<TrackInfo>().AsReadOnly());
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
        return (vm, sleepTimerService);
    }

    [AvaloniaFact]
    public void SleepTimerPanel_RendersWithoutException()
    {
        var (vm, _) = MakePlayerViewModel();
        var panel = new SleepTimerPanel { DataContext = vm };
        var window = new Window { Content = panel, Width = 400, Height = 600 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void SleepTimerPanel_HasPresetButtons()
    {
        var (vm, _) = MakePlayerViewModel();
        var panel = new SleepTimerPanel { DataContext = vm };
        var window = new Window { Content = panel, Width = 400, Height = 600 };
        window.Show();

        panel.Btn15.Should().NotBeNull("15 min button must exist");
        panel.Btn30.Should().NotBeNull("30 min button must exist");
        panel.Btn45.Should().NotBeNull("45 min button must exist");
        panel.Btn60.Should().NotBeNull("1 hour button must exist");
        panel.Btn120.Should().NotBeNull("2 hour button must exist");

        window.Close();
    }

    [AvaloniaFact]
    public void SleepTimerPanel_CloseButton_Exists()
    {
        var (vm, _) = MakePlayerViewModel();
        var panel = new SleepTimerPanel { DataContext = vm };
        var window = new Window { Content = panel, Width = 400, Height = 600 };
        window.Show();

        panel.CloseButton.Should().NotBeNull("panel must have a close button");
        panel.CloseButton!.Command.Should().NotBeNull("close button must have a command bound");
        window.Close();
    }

    [AvaloniaFact]
    public void SleepTimerPanel_CancelButton_Exists()
    {
        var (vm, _) = MakePlayerViewModel();
        var panel = new SleepTimerPanel { DataContext = vm };
        var window = new Window { Content = panel, Width = 400, Height = 600 };
        window.Show();

        panel.CancelButton.Should().NotBeNull("panel must have a cancel button");
        window.Close();
    }

    [AvaloniaFact]
    public void OpenSleepTimerCommand_SetsIsSleepTimerPanelOpenTrue()
    {
        var (vm, _) = MakePlayerViewModel();

        vm.OpenSleepTimerCommand.Execute(null);

        vm.IsSleepTimerPanelOpen.Should().BeTrue();
    }

    [AvaloniaFact]
    public void CloseSleepTimerPanelCommand_SetsIsSleepTimerPanelOpenFalse()
    {
        var (vm, _) = MakePlayerViewModel();
        vm.OpenSleepTimerCommand.Execute(null);
        vm.IsSleepTimerPanelOpen.Should().BeTrue();

        vm.CloseSleepTimerPanelCommand.Execute(null);

        vm.IsSleepTimerPanelOpen.Should().BeFalse();
    }

    [AvaloniaFact]
    public void SetSleepTimerCommand_CallsServiceAndClosesPanel()
    {
        var (vm, sleepSvc) = MakePlayerViewModel();
        vm.OpenSleepTimerCommand.Execute(null);

        vm.SetSleepTimerCommand.Execute("0:30:00");

        sleepSvc.Received(1).SetTimer(TimeSpan.FromMinutes(30));
        vm.IsSleepTimerPanelOpen.Should().BeFalse("panel should close after setting timer");
    }

    [AvaloniaFact]
    public void CancelSleepTimerCommand_CallsServiceCancelAndClosesPanel()
    {
        var (vm, sleepSvc) = MakePlayerViewModel();
        vm.OpenSleepTimerCommand.Execute(null);

        vm.CancelSleepTimerCommand.Execute(null);

        sleepSvc.Received(1).Cancel();
        vm.IsSleepTimerPanelOpen.Should().BeFalse("panel should close after cancelling timer");
    }

    [AvaloniaFact]
    public void SleepTimerPanel_IsVisibleInOsd_WhenIsSleepTimerPanelOpenIsTrue()
    {
        var (vm, _) = MakePlayerViewModel();
        var osd = new OsdOverlay { DataContext = vm };
        var window = new Window { Content = osd, Width = 1280, Height = 720 };
        window.Show();

        // Initially closed
        var panelBefore = FindDescendant<SleepTimerPanel>(osd);
        panelBefore.Should().NotBeNull("SleepTimerPanel must exist in OsdOverlay visual tree");
        panelBefore!.IsVisible.Should().BeFalse("panel should be hidden when IsSleepTimerPanelOpen is false");

        // Open
        vm.OpenSleepTimerCommand.Execute(null);

        panelBefore.IsVisible.Should().BeTrue("panel should be visible when IsSleepTimerPanelOpen is true");
        window.Close();
    }

    private static T? FindDescendant<T>(Control root) where T : Control
    {
        foreach (var child in root.GetVisualDescendants().OfType<T>())
            return child;
        return null;
    }
}
