using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Application.Services;
using Crispy.UI.Controls;
using Crispy.UI.Navigation;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// Tests for AppShell + AppShellViewModel: smoke render, layer visibility, and state transitions.
/// </summary>
[Trait("Category", "UI")]
public class AppShellTests
{
    // ─── Factory helpers ──────────────────────────────────────────────────────

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

    private static MainViewModel BuildNavVm()
    {
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(false);
        nav.CurrentViewModel.Returns((ViewModelBase?)null);
        return new MainViewModel(nav);
    }

    private static AppShellViewModel BuildVm()
        => new AppShellViewModel(BuildPlayerVm(), BuildNavVm());

    // ─── AppShellViewModel unit tests (no headless needed) ───────────────────

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_DefaultState_ContentVisibleVideoHidden()
    {
        var vm = BuildVm();

        vm.IsContentVisible.Should().BeTrue("content layer is visible by default");
        vm.IsVideoVisible.Should().BeFalse("video layer starts hidden until playback starts");
        vm.IsPlayerOverlayVisible.Should().BeFalse("OSD starts hidden");
        vm.IsMiniPlayerVisible.Should().BeFalse("mini-player hidden when not playing");
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_EnterWatchingMode_ShowsVideoAndOsd_HidesContent()
    {
        var vm = BuildVm();

        vm.EnterWatchingMode();

        vm.IsVideoVisible.Should().BeTrue();
        vm.IsContentVisible.Should().BeFalse();
        vm.IsPlayerOverlayVisible.Should().BeTrue();
        vm.IsMiniPlayerVisible.Should().BeFalse();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_EnterBrowsingMode_ShowsContent_HidesOsd()
    {
        var vm = BuildVm();
        vm.EnterWatchingMode(); // put into watching mode first

        vm.EnterBrowsingMode();

        vm.IsContentVisible.Should().BeTrue();
        vm.IsPlayerOverlayVisible.Should().BeFalse();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_EnterBrowsingMode_ShowsMiniPlayer_WhenVideoVisible()
    {
        var vm = BuildVm();
        vm.EnterWatchingMode(); // IsVideoVisible = true

        vm.EnterBrowsingMode();

        vm.IsMiniPlayerVisible.Should().BeTrue("mini-player shown when video active and browsing");
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_EnterBrowsingMode_HidesMiniPlayer_WhenNoVideo()
    {
        var vm = BuildVm();
        // IsVideoVisible is false by default

        vm.EnterBrowsingMode();

        vm.IsMiniPlayerVisible.Should().BeFalse("no mini-player if nothing is playing");
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_PlayerProperty_ReturnsSameInstance()
    {
        var player = BuildPlayerVm();
        var nav = BuildNavVm();
        var vm = new AppShellViewModel(player, nav);

        vm.Player.Should().BeSameAs(player);
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_NavigationProperty_ReturnsSameInstance()
    {
        var player = BuildPlayerVm();
        var nav = BuildNavVm();
        var vm = new AppShellViewModel(player, nav);

        vm.Navigation.Should().BeSameAs(nav);
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_ToggleMiniPlayer_WhenWatching_EntersBrowsingMode()
    {
        var vm = BuildVm();
        vm.EnterWatchingMode();

        vm.ToggleMiniPlayer();

        vm.IsContentVisible.Should().BeTrue("toggle from watching → browsing");
        vm.IsPlayerOverlayVisible.Should().BeFalse();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_ToggleMiniPlayer_WhenBrowsing_EntersWatchingMode()
    {
        var vm = BuildVm();
        vm.EnterWatchingMode();   // sets IsVideoVisible = true
        vm.EnterBrowsingMode();   // back to browsing

        vm.ToggleMiniPlayer();

        vm.IsContentVisible.Should().BeFalse("toggle from browsing → watching");
        vm.IsPlayerOverlayVisible.Should().BeTrue();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void AppShellViewModel_ToggleMiniPlayer_DoesNothing_WhenNoVideo()
    {
        var vm = BuildVm();
        // IsVideoVisible = false (default)

        vm.ToggleMiniPlayer();

        vm.IsContentVisible.Should().BeTrue("state unchanged when no video");
        vm.IsPlayerOverlayVisible.Should().BeFalse();
    }

    // ─── Fullscreen unit tests ────────────────────────────────────────────────

    [Fact]
    [Trait("Category", "Unit")]
    public void ToggleFullscreen_SetsIsFullscreenTrue_WhenFalse()
    {
        var vm = BuildVm();
        vm.IsFullscreen.Should().BeFalse("starts non-fullscreen");

        vm.ToggleFullscreen();

        vm.IsFullscreen.Should().BeTrue();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void ToggleFullscreen_SetsIsFullscreenFalse_WhenTrue()
    {
        var vm = BuildVm();
        vm.ToggleFullscreen(); // enter fullscreen

        vm.ToggleFullscreen(); // exit fullscreen

        vm.IsFullscreen.Should().BeFalse();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void ToggleFullscreen_HidesContent_WhenEnteringFullscreen()
    {
        var vm = BuildVm();
        vm.IsContentVisible.Should().BeTrue("precondition: content visible before fullscreen");

        vm.ToggleFullscreen();

        vm.IsContentVisible.Should().BeFalse("content layer hidden in fullscreen");
        vm.IsPlayerOverlayVisible.Should().BeTrue("OSD shown in fullscreen");
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void ToggleFullscreen_RestoresContentVisible_WhenExitingFullscreen()
    {
        var vm = BuildVm();
        // Default: content visible, no overlay
        vm.ToggleFullscreen(); // enter — saves state
        vm.ToggleFullscreen(); // exit  — restores state

        vm.IsContentVisible.Should().BeTrue("content restored after exiting fullscreen");
        vm.IsFullscreen.Should().BeFalse();
    }

    // ─── AppShell headless render tests ───────────────────────────────────────

    [AvaloniaFact]
    public void AppShell_RendersWithoutException_WhenShownWithViewModel()
    {
        var vm = BuildVm();

        var act = () =>
        {
            var window = HeadlessTestHelpers.CreateWindow<AppShell>(vm);
            window.Close();
        };

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void AppShell_HasNavigationRailControl()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<AppShell>(vm);

        var shell = window.GetVisualDescendants()
            .OfType<AppShell>()
            .FirstOrDefault();
        shell.Should().NotBeNull("AppShell must be in the visual tree");

        var rail = shell!.FindControl<NavigationRail>("NavRail");
        rail.Should().NotBeNull("AppShell must contain a NavigationRail named NavRail");

        window.Close();
    }

    // OsdOverlay is inside VideoView.Content (floating transparent overlay).
    // VideoView (NativeControlHost) does not render its content in headless mode,
    // so OsdOverlay is not in the visual tree during headless tests.
    // Visual verification required: run the app and confirm OSD renders on top of video.

    [AvaloniaFact]
    public void AppShell_ContentLayer_IsVisible_ByDefault()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<AppShell>(vm);

        var shell = window.GetVisualDescendants()
            .OfType<AppShell>()
            .FirstOrDefault();
        shell.Should().NotBeNull();

        var contentLayer = shell!.FindControl<Grid>("ContentLayer");
        contentLayer.Should().NotBeNull();
        contentLayer!.IsVisible.Should().BeTrue("content layer defaults to visible");

        window.Close();
    }

    // VideoView (NativeControlHost) requires a real window — not testable in Avalonia.Headless.
    // Video layer visibility is verified indirectly via AppShellViewModel.IsVideoVisible unit tests above.
}
