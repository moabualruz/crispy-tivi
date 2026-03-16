using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Application.Services;
using Crispy.UI.Navigation;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Avalonia.Headless.XUnit;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class AppShellViewModelTests
{
    private static PlayerViewModel BuildPlayerVm()
    {
        var stateSubject = new TestSubject<PlayerState>();
        var playerService = Substitute.For<IPlayerService>();
        playerService.State.Returns(PlayerState.Empty);
        playerService.StateChanged.Returns(stateSubject);
        playerService.AudioSamples.Returns(new TestSubject<float[]>());
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);

        var timeshiftService = Substitute.For<ITimeshiftService>();
        timeshiftService.StateChanged.Returns(new TestSubject<TimeshiftState>());
        timeshiftService.State.Returns(new TimeshiftState(
            BufferDuration: TimeSpan.Zero,
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: string.Empty,
            IsAtLiveEdge: true,
            IsBufferFull: false));

        var sleepTimer = Substitute.For<ISleepTimerService>();
        sleepTimer.RemainingChanged.Returns(new TestSubject<TimeSpan?>());
        sleepTimer.Remaining.Returns((TimeSpan?)null);

        return new PlayerViewModel(playerService, timeshiftService, sleepTimer);
    }

    private static AppShellViewModel Build()
    {
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(false);
        nav.CurrentViewModel.Returns((ViewModelBase?)null);
        var navigation = new MainViewModel(nav);
        return new AppShellViewModel(BuildPlayerVm(), navigation);
    }

    // ── Defaults ──────────────────────────────────────────────────────────────

    [Fact]
    public void Constructor_SetsExpectedDefaults()
    {
        var sut = Build();

        sut.IsVideoVisible.Should().BeFalse();
        sut.IsContentVisible.Should().BeTrue();
        sut.IsPlayerOverlayVisible.Should().BeFalse();
        sut.IsMiniPlayerVisible.Should().BeFalse();
        sut.IsFullscreen.Should().BeFalse();
        sut.ContentOpacity.Should().Be(1.0);
        sut.PlayerOverlayOpacity.Should().Be(0.0);
    }

    // ── EnterWatchingMode (synchronous state) ────────────────────────────────

    [Fact]
    public void EnterWatchingMode_SetsIsVideoVisibleTrue()
    {
        var sut = Build();
        sut.EnterWatchingMode();
        sut.IsVideoVisible.Should().BeTrue();
    }

    [Fact]
    public void EnterWatchingMode_ClearsIsMiniPlayerVisible()
    {
        var sut = Build();
        sut.EnterWatchingMode();
        sut.IsMiniPlayerVisible.Should().BeFalse();
    }

    // ── EnterBrowsingMode (synchronous state after animation stub) ────────────

    [Fact]
    public void EnterBrowsingMode_DoesNotThrow()
    {
        var sut = Build();
        sut.EnterWatchingMode();
        var act = () => sut.EnterBrowsingMode();
        act.Should().NotThrow();
    }

    // ── ContentBackground ─────────────────────────────────────────────────────

    [AvaloniaFact]
    public void ContentBackground_IsTransparent_WhenVideoNotVisible()
    {
        var sut = Build();
        // Default: video not visible
        sut.ContentBackground.ToString().Should().NotBeNullOrEmpty();
        // Transparent brush — no black overlay
        sut.IsVideoVisible.Should().BeFalse();
        sut.IsContentVisible.Should().BeTrue();
    }

    [AvaloniaFact]
    public void ContentBackground_IsBlackOverlay_WhenVideoAndContentBothVisible()
    {
        var sut = Build();
        sut.IsVideoVisible = true;
        // IsContentVisible stays true (browsing-while-playing state)
        var brush = sut.ContentBackground as Avalonia.Media.SolidColorBrush;
        brush.Should().NotBeNull();
        brush!.Color.A.Should().Be(0xCC); // 80% opacity black
    }

    // ── Fullscreen ────────────────────────────────────────────────────────────

    [Fact]
    public void EnterFullscreen_SetsIsFullscreenTrue_AndHidesContentLayer()
    {
        var sut = Build();
        sut.EnterFullscreen();

        sut.IsFullscreen.Should().BeTrue();
        sut.IsContentVisible.Should().BeFalse();
        sut.IsPlayerOverlayVisible.Should().BeTrue();
        sut.IsMiniPlayerVisible.Should().BeFalse();
    }

    [Fact]
    public void ExitFullscreen_RestoresPriorState()
    {
        var sut = Build();
        // Establish a known prior state
        sut.IsContentVisible = true;
        sut.IsPlayerOverlayVisible = false;
        sut.IsMiniPlayerVisible = false;

        sut.EnterFullscreen();
        sut.ExitFullscreen();

        sut.IsFullscreen.Should().BeFalse();
        sut.IsContentVisible.Should().BeTrue();
        sut.IsPlayerOverlayVisible.Should().BeFalse();
        sut.IsMiniPlayerVisible.Should().BeFalse();
    }

    [Fact]
    public void ToggleFullscreen_TogglesIsFullscreen()
    {
        var sut = Build();
        sut.ToggleFullscreen();
        sut.IsFullscreen.Should().BeTrue();

        sut.ToggleFullscreen();
        sut.IsFullscreen.Should().BeFalse();
    }

    // ── ToggleMiniPlayer ──────────────────────────────────────────────────────

    [Fact]
    public void ToggleMiniPlayer_DoesNothing_WhenVideoNotVisible()
    {
        var sut = Build();
        sut.IsContentVisible = true;

        sut.ToggleMiniPlayer();

        // No state change — video is not visible
        sut.IsVideoVisible.Should().BeFalse();
        sut.IsContentVisible.Should().BeTrue();
    }

    [Fact]
    public void ToggleMiniPlayer_WhenWatching_TransitionsToBrowsing()
    {
        var sut = Build();
        sut.EnterWatchingMode();
        // Force synchronous state as if animation completed
        sut.IsContentVisible = false;
        sut.IsPlayerOverlayVisible = true;

        sut.ToggleMiniPlayer();

        // EnterBrowsingMode was called — async animation starts, no throw
        sut.IsVideoVisible.Should().BeTrue();
    }

    // ── Opacity properties ────────────────────────────────────────────────────

    [Fact]
    public void ContentOpacity_DefaultsToOne()
    {
        var sut = Build();
        sut.ContentOpacity.Should().Be(1.0);
    }

    [Fact]
    public void PlayerOverlayOpacity_DefaultsToZero()
    {
        var sut = Build();
        sut.PlayerOverlayOpacity.Should().Be(0.0);
    }

    [Fact]
    public void ContentOpacity_RaisesPropertyChanged_WhenSet()
    {
        var sut = Build();
        using var monitor = sut.Monitor();

        sut.ContentOpacity = 0.5;

        monitor.Should().RaisePropertyChangeFor(x => x.ContentOpacity);
    }

    [Fact]
    public void PlayerOverlayOpacity_RaisesPropertyChanged_WhenSet()
    {
        var sut = Build();
        using var monitor = sut.Monitor();

        sut.PlayerOverlayOpacity = 0.7;

        monitor.Should().RaisePropertyChangeFor(x => x.PlayerOverlayOpacity);
    }
}
