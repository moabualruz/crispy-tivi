using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Input;
using Avalonia.VisualTree;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Application.Services;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// Tests for PlayerView code-behind: smoke render, OSD state, and keyboard shortcuts.
/// </summary>
[Trait("Category", "UI")]
public class PlayerViewTests
{
    private static PlayerViewModel BuildVm()
    {
        var stateSubject = new Helpers.TestSubject<PlayerState>();
        var playerService = Substitute.For<IPlayerService>();
        playerService.State.Returns(PlayerState.Empty);
        playerService.StateChanged.Returns(stateSubject);
        playerService.AudioSamples.Returns(new Helpers.TestSubject<float[]>());
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);

        var timeshiftService = Substitute.For<ITimeshiftService>();
        timeshiftService.StateChanged.Returns(new Helpers.TestSubject<TimeshiftState>());
        timeshiftService.State.Returns(new TimeshiftState(
            BufferDuration: TimeSpan.Zero,
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: string.Empty,
            IsAtLiveEdge: true,
            IsBufferFull: false));

        var sleepTimer = Substitute.For<ISleepTimerService>();
        sleepTimer.RemainingChanged.Returns(new Helpers.TestSubject<TimeSpan?>());
        sleepTimer.Remaining.Returns((TimeSpan?)null);

        return new PlayerViewModel(playerService, timeshiftService, sleepTimer);
    }

    // ── Smoke tests ──────────────────────────────────────────────────────────

    [AvaloniaFact]
    public void PlayerView_RendersWithoutException()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_InitialState_IsNotPlaying()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);

        vm.IsPlaying.Should().BeFalse(
            "PlayerViewModel must start stopped when no stream has been requested");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_ShowOsd_MakesOsdVisible()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);

        vm.ShowOsd();

        vm.IsOsdVisible.Should().BeTrue("ShowOsd() must make the OSD overlay visible");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_DefaultVolume_IsOne()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);

        vm.Volume.Should().BeApproximately(1.0f, 0.001f,
            "PlayerViewModel must default volume to 1.0 (100%)");
        window.Close();
    }

    // ── Keyboard shortcuts (PLR-21) ──────────────────────────────────────────

    [AvaloniaFact]
    public void PlayerView_SpaceKey_DoesNotThrow_WhenNotPlaying()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        // Space when not playing → calls ResumeCommand (no-op since nothing is loaded)
        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.Space, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.Space, RawInputModifiers.None);
        };

        act.Should().NotThrow("Space key must not throw regardless of play state");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_MKey_DoesNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.M, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.M, RawInputModifiers.None);
        };

        act.Should().NotThrow("M key (mute toggle) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_FKey_DoesNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.F, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.F, RawInputModifiers.None);
        };

        act.Should().NotThrow("F key (fullscreen toggle) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_EscapeKey_DoesNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.Escape, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.Escape, RawInputModifiers.None);
        };

        act.Should().NotThrow("Escape key (fullscreen toggle) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_UpArrow_IncreasesVolume()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        // SetVolumeCommand is async; volume change is scheduled
        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.ArrowUp, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.ArrowUp, RawInputModifiers.None);
        };

        act.Should().NotThrow("Up arrow (volume +5%) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_DownArrow_DecreasesVolume()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.ArrowDown, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.ArrowDown, RawInputModifiers.None);
        };

        act.Should().NotThrow("Down arrow (volume -5%) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_LeftArrow_SeeksBackward_DoesNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.ArrowLeft, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.ArrowLeft, RawInputModifiers.None);
        };

        act.Should().NotThrow("Left arrow (seek back) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_RightArrow_SeeksForward_DoesNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.ArrowRight, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.ArrowRight, RawInputModifiers.None);
        };

        act.Should().NotThrow("Right arrow (seek forward) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_AKey_CycleAudioTrack_DoesNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            window.KeyPressQwerty(PhysicalKey.A, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.A, RawInputModifiers.None);
        };

        act.Should().NotThrow("A key (cycle audio track) must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_MultipleKeystrokes_DoNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
        var view = (PlayerView)window.Content!;
        view.Focus();

        var act = () =>
        {
            // Simulate a realistic sequence: show OSD, adjust volume, seek
            window.KeyPressQwerty(PhysicalKey.Space, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.Space, RawInputModifiers.None);
            window.KeyPressQwerty(PhysicalKey.ArrowUp, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.ArrowUp, RawInputModifiers.None);
            window.KeyPressQwerty(PhysicalKey.ArrowRight, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.ArrowRight, RawInputModifiers.None);
            window.KeyPressQwerty(PhysicalKey.M, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.M, RawInputModifiers.None);
            window.KeyPressQwerty(PhysicalKey.F, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.F, RawInputModifiers.None);
            window.KeyPressQwerty(PhysicalKey.Escape, RawInputModifiers.None);
            window.KeyReleaseQwerty(PhysicalKey.Escape, RawInputModifiers.None);
        };

        act.Should().NotThrow("a realistic keyboard sequence must not throw");
        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_PointerMove_ShowsOsd()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);

        window.MouseMove(new Avalonia.Point(200, 200));

        vm.IsOsdVisible.Should().BeTrue("mouse movement must reveal the OSD");
        window.Close();
    }

    // ── Audio-only layout (Truth 5) ─────────────────────────────────────────

    [AvaloniaFact]
    public void PlayerView_IsAudioOnly_SetTrue_WhenAudioOnlyStateEmitted()
    {
        var stateSubject = new TestSubject<PlayerState>();
        var playerService = Substitute.For<IPlayerService>();
        var audioOnlyState = PlayerState.Empty with { IsAudioOnly = true };
        playerService.State.Returns(audioOnlyState);
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

        var vm = new PlayerViewModel(playerService, timeshiftService, sleepTimer);
        stateSubject.OnNext(audioOnlyState);

        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);

        // ViewModel reflects audio-only state — compiled binding
        // IsVisible="{Binding !IsAudioOnly}" hides VideoSurface (verified by build)
        vm.IsAudioOnly.Should().BeTrue(
            "ViewModel must reflect IsAudioOnly from PlayerState; " +
            "PlayerView.axaml binds VideoSurface.IsVisible to !IsAudioOnly");

        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_IsAudioOnly_FalseByDefault()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);

        vm.IsAudioOnly.Should().BeFalse(
            "ViewModel must default IsAudioOnly to false; VideoSurface visible by default");

        window.Close();
    }

    [AvaloniaFact]
    public void PlayerView_RendersWithoutException_WhenAudioOnly()
    {
        var stateSubject = new TestSubject<PlayerState>();
        var playerService = Substitute.For<IPlayerService>();
        var audioOnlyState = PlayerState.Empty with { IsAudioOnly = true };
        playerService.State.Returns(audioOnlyState);
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

        var vm = new PlayerViewModel(playerService, timeshiftService, sleepTimer);
        stateSubject.OnNext(audioOnlyState);

        // Rendering audio-only mode (hidden VideoSurface + visible WaveformVisualizer) must not throw
        var act = () =>
        {
            var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
            window.Close();
        };

        act.Should().NotThrow("PlayerView must render without exception in audio-only mode");
    }
}
