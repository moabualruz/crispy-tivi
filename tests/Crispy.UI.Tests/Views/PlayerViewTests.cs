using Avalonia.Headless.XUnit;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// Smoke tests verifying that PlayerView mounts without exceptions under the headless
/// Avalonia platform, and that OSD / volume state is correct at startup.
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
}
