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
/// Full implementation target: Wave 2 (03-02).
/// </summary>
[Trait("Category", "Unit")]
public class PlayerViewModelTests
{
    private readonly IPlayerService _playerService;
    private readonly PlayerViewModel _sut;

    public PlayerViewModelTests()
    {
        _playerService = Substitute.For<IPlayerService>();
        _playerService.State.Returns(PlayerState.Empty);
        _playerService.StateChanged.Returns(new TestSubject<PlayerState>());
        _playerService.AudioSamples.Returns(new TestSubject<float[]>());
        _playerService.AudioTracks.Returns([]);
        _playerService.SubtitleTracks.Returns([]);

        _sut = new PlayerViewModel(_playerService);
    }

    [Fact]
    public void SkipIntro_IsVisible_WhenPositionWithinIntroMarker()
    {
        // Arrange — simulate state where position is within the 0–90s intro window
        var state = PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = true,
            Position = TimeSpan.FromSeconds(45),
        };

        // Act — Wave 2 implementation must observe StateChanged and set IsSkipIntroVisible
        _sut.PlayerState = state;

        // RED: IsSkipIntroVisible will be false until the real implementation
        // subscribes to StateChanged and evaluates intro-marker boundaries.
        _sut.IsSkipIntroVisible.Should().BeTrue(
            "Skip Intro button must appear when playback position falls within the intro marker window");
    }

    [Fact]
    public void SkipIntro_IsNotVisible_WhenNoMarkers()
    {
        // Arrange — default empty state has no markers
        _sut.PlayerState = PlayerState.Empty;

        // Assert — safe default: no skip button when there are no markers
        // This will pass immediately because the stub initialises IsSkipIntroVisible = false.
        _sut.IsSkipIntroVisible.Should().BeFalse(
            "Skip Intro button must be hidden when no intro marker is present");
    }

    [Fact]
    public void AutoPlayCountdown_Starts_WhenCreditsMarkerReached()
    {
        // Arrange — simulate position near the end of a VOD episode (credits region)
        var state = PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = true,
            Position = TimeSpan.FromMinutes(44),
            Duration = TimeSpan.FromMinutes(45),
        };

        // Act
        _sut.PlayerState = state;

        // RED: AutoPlayCountdownSeconds will be 0 until Wave 2 implements credits detection
        _sut.IsAutoPlayCountdownVisible.Should().BeTrue(
            "Auto-play countdown must start when playback enters the credits region");
        _sut.AutoPlayCountdownSeconds.Should().BeGreaterThan(0,
            "Auto-play countdown must start at a positive value");
    }

    [Fact]
    public void AreYouStillWatching_Fires_AfterThreeEpisodes()
    {
        // Arrange — simulate the third episode completing without user interaction
        var thirdEpisodeComplete = PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = false,
            Position = TimeSpan.FromMinutes(45),
            Duration = TimeSpan.FromMinutes(45),
        };

        // Act — Wave 2 must track a consecutive-episode counter
        _sut.PlayerState = thirdEpisodeComplete;

        // RED: IsAreYouStillWatchingVisible will be false until the counter is implemented
        _sut.IsAreYouStillWatchingVisible.Should().BeTrue(
            "\"Are You Still Watching?\" prompt must appear after three consecutive episodes without user interaction");
    }

    [Fact]
    public void Speed_IsDisabled_WhenIsLiveTrue()
    {
        // Arrange
        var liveState = PlayerState.Empty with
        {
            Mode = PlaybackMode.Live,
            IsLive = true,
            IsPlaying = true,
        };

        // Act
        _sut.PlayerState = liveState;

        // RED: IsSpeedEnabled will be true (default) until the ViewModel binds it to IsLive
        _sut.IsSpeedEnabled.Should().BeFalse(
            "Speed controls must be disabled for live streams (no meaningful fast-forward on live TV)");
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
        _sut.PlayerState = hdState;

        // RED: QualityDisplay will be empty until the ViewModel computes it from video dimensions
        _sut.QualityDisplay.Should().NotBeNullOrEmpty(
            "QualityDisplay must show a human-readable resolution label (e.g. \"1080p\") from PlayerState dimensions");
        _sut.QualityDisplay.Should().Contain("1080",
            "QualityDisplay must include the vertical resolution value");
    }
}
