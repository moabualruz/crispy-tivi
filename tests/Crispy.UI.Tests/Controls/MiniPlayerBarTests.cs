using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.LogicalTree;
using Avalonia.VisualTree;

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
public class MiniPlayerBarTests
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

        var vm = new PlayerViewModel(playerService, timeshiftService, sleepTimerService);
        return (vm, stateSubject);
    }

    [AvaloniaFact]
    public void MiniPlayerBar_RendersWithoutException_WhenNoDataContext()
    {
        var control = new MiniPlayerBar();
        var window = new Window { Content = control, Width = 800, Height = 64 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerBar_RendersWithoutException_WhenPlayerViewModelSet()
    {
        var (vm, _) = MakePlayerViewModel();
        var control = new MiniPlayerBar { DataContext = vm };
        var window = new Window { Content = control, Width = 800, Height = 64 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerBar_ShowsChannelName_WhenHasActiveMedia()
    {
        var (vm, stateSubject) = MakePlayerViewModel();
        vm.ChannelName = "BBC One";
        vm.HasActiveMedia = true;

        var control = new MiniPlayerBar { DataContext = vm };
        var window = new Window { Content = control, Width = 800, Height = 64 };
        window.Show();

        var textBlocks = control.GetVisualDescendants().OfType<TextBlock>().ToList();
        var channelText = textBlocks.FirstOrDefault(t => t.Text == "BBC One");

        channelText.Should().NotBeNull("MiniPlayerBar should display channel name");
        channelText!.IsVisible.Should().BeTrue();

        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerBar_ShowsFallback_WhenNoActiveMedia()
    {
        var (vm, _) = MakePlayerViewModel();
        vm.HasActiveMedia = false;

        var control = new MiniPlayerBar { DataContext = vm };
        var window = new Window { Content = control, Width = 800, Height = 64 };
        window.Show();

        var textBlocks = control.GetVisualDescendants().OfType<TextBlock>().ToList();
        var fallback = textBlocks.FirstOrDefault(t => t.Text == "No media playing");

        fallback.Should().NotBeNull("MiniPlayerBar should show fallback text when not playing");
        fallback!.IsVisible.Should().BeTrue();

        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerBar_ShowsCurrentProgramme_WhenHasActiveMedia()
    {
        var (vm, _) = MakePlayerViewModel();
        vm.HasActiveMedia = true;
        vm.CurrentProgramme = "News at Ten";

        var control = new MiniPlayerBar { DataContext = vm };
        var window = new Window { Content = control, Width = 800, Height = 64 };
        window.Show();

        var textBlocks = control.GetVisualDescendants().OfType<TextBlock>().ToList();
        var programme = textBlocks.FirstOrDefault(t => t.Text == "News at Ten");

        programme.Should().NotBeNull("MiniPlayerBar should display current programme");
        programme!.IsVisible.Should().BeTrue();

        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerBar_ShowsResumeButton_WhenPausedWithActiveMedia()
    {
        var (vm, _) = MakePlayerViewModel();
        vm.HasActiveMedia = true;
        vm.IsPlaying = false;

        var control = new MiniPlayerBar { DataContext = vm };
        var window = new Window { Content = control, Width = 800, Height = 64 };
        window.Show();

        var buttons = control.GetVisualDescendants().OfType<Button>().ToList();

        // Resume button (play icon) should be visible, pause button hidden
        var resumeButton = buttons.FirstOrDefault(b => b.Content?.ToString() == "\u25B6" && b.IsVisible);
        var pauseButton = buttons.FirstOrDefault(b => b.Content?.ToString() == "\u23F8" && b.IsVisible);

        resumeButton.Should().NotBeNull("Resume button should be visible when paused");
        pauseButton.Should().BeNull("Pause button should be hidden when paused");

        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerBar_ShowsPauseButton_WhenPlaying()
    {
        var (vm, _) = MakePlayerViewModel();
        vm.HasActiveMedia = true;
        vm.IsPlaying = true;

        var control = new MiniPlayerBar { DataContext = vm };
        var window = new Window { Content = control, Width = 800, Height = 64 };
        window.Show();

        var buttons = control.GetVisualDescendants().OfType<Button>().ToList();

        var pauseButton = buttons.FirstOrDefault(b => b.Content?.ToString() == "\u23F8" && b.IsVisible);
        var resumeButton = buttons.FirstOrDefault(b => b.Content?.ToString() == "\u25B6" && b.IsVisible);

        pauseButton.Should().NotBeNull("Pause button should be visible when playing");
        resumeButton.Should().BeNull("Resume button should be hidden when playing");

        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerBar_ResumeButtonDisabled_WhenNoActiveMedia()
    {
        var (vm, _) = MakePlayerViewModel();
        vm.HasActiveMedia = false;
        vm.IsPlaying = false;

        var control = new MiniPlayerBar { DataContext = vm };
        var window = new Window { Content = control, Width = 800, Height = 64 };
        window.Show();

        var buttons = control.GetVisualDescendants().OfType<Button>().ToList();
        var resumeButton = buttons.FirstOrDefault(b => b.Content?.ToString() == "\u25B6" && b.IsVisible);

        resumeButton.Should().NotBeNull("Resume button should be visible when not playing");
        resumeButton!.IsEnabled.Should().BeFalse("Resume button should be disabled with no active media");

        window.Close();
    }
}
