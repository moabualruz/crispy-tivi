using Avalonia.Controls;
using Avalonia.Headless.XUnit;

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

[Trait("Category", "Unit")]
public class OsdOverlayTests
{
    private static PlayerViewModel MakePlayerViewModel()
    {
        var playerService = Substitute.For<IPlayerService>();
        var timeshiftService = Substitute.For<ITimeshiftService>();
        var sleepTimerService = Substitute.For<ISleepTimerService>();

        var stateSubject = new TestSubject<PlayerState>();
        playerService.StateChanged.Returns(stateSubject);
        playerService.State.Returns(PlayerState.Empty);

        var timeshiftSubject = new TestSubject<TimeshiftState>();
        timeshiftService.StateChanged.Returns(timeshiftSubject);

        var sleepSubject = new TestSubject<TimeSpan?>();
        sleepTimerService.RemainingChanged.Returns(sleepSubject);
        sleepTimerService.Remaining.Returns((TimeSpan?)null);

        return new PlayerViewModel(playerService, timeshiftService, sleepTimerService);
    }

    [AvaloniaFact]
    public void OsdOverlay_RendersWithoutException_WhenShownWithNoDataContext()
    {
        var control = new OsdOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 200 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_RendersWithoutException_WhenPlayerViewModelSet()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay { DataContext = vm };
        var window = new Window { Content = control, Width = 1280, Height = 200 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_WiresSeekBars_WhenDataContextIsPlayerViewModel()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();

        // Setting DataContext after Show triggers OnDataContextChanged
        var act = () => { control.DataContext = vm; };

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_DoesNotThrow_WhenDataContextChangedToNull()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay { DataContext = vm };
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();

        var act = () => { control.DataContext = null; };

        act.Should().NotThrow();
        window.Close();
    }
}
