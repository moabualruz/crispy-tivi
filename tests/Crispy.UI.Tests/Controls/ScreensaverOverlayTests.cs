using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Input;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Application.Services;
using Crispy.UI.Controls;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Crispy.UI.Tests.Helpers;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "UI")]
public class ScreensaverOverlayTests
{
    private static PlayerViewModel MakePlayerViewModel()
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

        var timeshiftSubject = new TestSubject<TimeshiftState>();
        timeshiftService.StateChanged.Returns(timeshiftSubject);
        timeshiftService.State.Returns(new TimeshiftState(
            BufferDuration: TimeSpan.Zero,
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: string.Empty,
            IsAtLiveEdge: true,
            IsBufferFull: false));

        var sleepSubject = new TestSubject<TimeSpan?>();
        sleepTimerService.RemainingChanged.Returns(sleepSubject);
        sleepTimerService.Remaining.Returns((TimeSpan?)null);

        return new PlayerViewModel(playerService, timeshiftService, sleepTimerService);
    }

    [AvaloniaFact]
    public void ScreensaverOverlay_RendersWithoutException_WhenShownWithNoDataContext()
    {
        var control = new ScreensaverOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 720 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void ScreensaverOverlay_RendersWithoutException_WhenPlayerViewModelSet()
    {
        var vm = MakePlayerViewModel();
        var control = new ScreensaverOverlay { DataContext = vm };
        var window = new Window { Content = control, Width = 1280, Height = 720 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void ScreensaverOverlay_CallsDismissScreensaver_OnPointerPressed_WhenPlayerViewModelBound()
    {
        var vm = MakePlayerViewModel();
        vm.IsScreensaverActive = true;

        var control = new ScreensaverOverlay { DataContext = vm };
        var window = new Window { Content = control, Width = 1280, Height = 720 };
        window.Show();

        window.MouseDown(new Point(100, 100), MouseButton.Left);

        vm.IsScreensaverActive.Should().BeFalse(
            "PointerPressed on ScreensaverOverlay must call DismissScreensaver() which sets IsScreensaverActive=false");

        window.Close();
    }

    [AvaloniaFact]
    public void ScreensaverOverlay_DoesNotThrow_WhenPointerPressedWithNullDataContext()
    {
        var control = new ScreensaverOverlay { DataContext = null };
        var window = new Window { Content = control, Width = 1280, Height = 720 };
        window.Show();

        var act = () => window.MouseDown(new Point(100, 100), MouseButton.Left);

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void ScreensaverOverlay_DoesNotThrow_WhenPointerPressedWithNonPlayerViewModelDataContext()
    {
        var control = new ScreensaverOverlay { DataContext = new object() };
        var window = new Window { Content = control, Width = 1280, Height = 720 };
        window.Show();

        var act = () => window.MouseDown(new Point(100, 100), MouseButton.Left);

        act.Should().NotThrow();
        window.Close();
    }
}
