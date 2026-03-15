using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for PlayerViewModel — verifies OSD reactive state derived from
/// IPlayerService state emissions (skip-intro, auto-play countdown, still-watching prompt).
/// </summary>
[Trait("Category", "Unit")]
public class PlayerViewModelTests
{
    private readonly IPlayerService _playerService;
    private readonly ITimeshiftService _timeshiftService;
    private readonly ISleepTimerService _sleepTimerService;
    private readonly TestSubject<PlayerState> _stateSubject;
    private readonly TestSubject<TimeshiftState> _timeshiftSubject;
    private readonly TestSubject<TimeSpan?> _sleepSubject;
    private readonly PlayerViewModel _sut;

    public PlayerViewModelTests()
    {
        _stateSubject = new TestSubject<PlayerState>();
        _timeshiftSubject = new TestSubject<TimeshiftState>();
        _sleepSubject = new TestSubject<TimeSpan?>();

        _playerService = Substitute.For<IPlayerService>();
        _playerService.State.Returns(PlayerState.Empty);
        _playerService.StateChanged.Returns(_stateSubject);
        _playerService.AudioSamples.Returns(new TestSubject<float[]>());
        _playerService.AudioTracks.Returns([]);
        _playerService.SubtitleTracks.Returns([]);

        _timeshiftService = Substitute.For<ITimeshiftService>();
        _timeshiftService.StateChanged.Returns(_timeshiftSubject);
        _timeshiftService.State.Returns(new TimeshiftState(
            TimeSpan.Zero, TimeSpan.Zero, DateTimeOffset.UtcNow,
            string.Empty, true, false));

        _sleepTimerService = Substitute.For<ISleepTimerService>();
        _sleepTimerService.RemainingChanged.Returns(_sleepSubject);
        _sleepTimerService.Remaining.Returns((TimeSpan?)null);

        _sut = new PlayerViewModel(_playerService, _timeshiftService, _sleepTimerService);
    }

    [Fact]
    public void ShowSkipIntro_IsTrue_WhenPositionWithinIntroMarker()
    {
        // Arrange — configure a 0–90s intro marker
        _sut.SetSegmentMarkers(
            intro: [new JellyfinSegmentMarker(TimeSpan.Zero, TimeSpan.FromSeconds(90))],
            credits: []);

        // Act — emit a state update with position inside the intro window
        var state = PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = true,
            Position = TimeSpan.FromSeconds(45),
            Duration = TimeSpan.FromMinutes(45),
        };
        _stateSubject.OnNext(state);

        // Assert
        _sut.ShowSkipIntro.Should().BeTrue(
            "Skip Intro button must appear when playback position falls within the intro marker window");
    }

    [Fact]
    public void ShowSkipIntro_IsFalse_WhenNoMarkers()
    {
        // Arrange — default: no markers set
        // Act — emit default state
        _stateSubject.OnNext(PlayerState.Empty);

        // Assert
        _sut.ShowSkipIntro.Should().BeFalse(
            "Skip Intro button must be hidden when no intro marker is present");
    }

    [Fact]
    public void ShowAutoPlayCountdown_IsTrue_WhenNearEndOfVod()
    {
        // Arrange — position within last 30s of a 45-minute VOD
        var state = PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = true,
            Position = TimeSpan.FromMinutes(44) + TimeSpan.FromSeconds(45),
            Duration = TimeSpan.FromMinutes(45),
        };

        // Act
        _stateSubject.OnNext(state);

        // Assert
        _sut.ShowAutoPlayCountdown.Should().BeTrue(
            "Auto-play countdown must start when playback enters the final 30 seconds of a VOD episode");
        _sut.AutoPlayCountdownSeconds.Should().BeGreaterThan(0,
            "Auto-play countdown must start at a positive value");
    }

    [Fact]
    public void IsSpeedEnabled_IsFalse_WhenIsLiveTrue()
    {
        // Arrange — live state
        var liveState = PlayerState.Empty with
        {
            Mode = PlaybackMode.Live,
            IsLive = true,
            IsPlaying = true,
        };

        // Act
        _stateSubject.OnNext(liveState);

        // Assert
        _sut.IsSpeedEnabled.Should().BeFalse(
            "Speed controls must be disabled for live streams (PLR-07)");
    }

    [Fact]
    public void QualityDisplay_ShowsResolution_FromPlayerState()
    {
        // Arrange
        var hdState = PlayerState.Empty with
        {
            IsPlaying = true,
            CurrentVideoWidth = 1920,
            CurrentVideoHeight = 1080,
        };

        // Act
        _stateSubject.OnNext(hdState);

        // Assert
        _sut.QualityDisplay.Should().NotBeNullOrEmpty(
            "QualityDisplay must show a human-readable resolution label from video dimensions");
        _sut.QualityDisplay.Should().Contain("1080",
            "QualityDisplay must include the vertical resolution value");
    }

    [Fact]
    public void IsTimeshifted_IsTrue_WhenModeIsTimeshifted()
    {
        // Arrange
        var timeshiftedState = PlayerState.Empty with
        {
            Mode = PlaybackMode.Timeshifted,
            IsLive = true,
            IsPlaying = true,
        };

        // Act
        _stateSubject.OnNext(timeshiftedState);

        // Assert
        _sut.IsTimeshifted.Should().BeTrue(
            "IsTimeshifted must be true when PlayerState.Mode is Timeshifted");
    }

    [Fact]
    public void ShowGoLive_IsTrue_WhenTimeshiftedAndNotAtLiveEdge()
    {
        // Arrange — emit timeshifted player state
        _stateSubject.OnNext(PlayerState.Empty with { Mode = PlaybackMode.Timeshifted, IsLive = true });

        // Emit timeshift state with offset (not at live edge)
        _timeshiftSubject.OnNext(new TimeshiftState(
            BufferDuration: TimeSpan.FromMinutes(2),
            Offset: TimeSpan.FromMinutes(-2),
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: "-2:00",
            IsAtLiveEdge: false,
            IsBufferFull: false));

        // Assert
        _sut.ShowGoLive.Should().BeTrue(
            "GO LIVE button must appear when player is timeshifted and not at the live edge");
    }
}
