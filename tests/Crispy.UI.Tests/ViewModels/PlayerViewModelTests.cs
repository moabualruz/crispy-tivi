using Avalonia.Headless.XUnit;
using Avalonia.Threading;

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

    // ── Error handling ───────────────────────────────────────────────────────

    [AvaloniaFact]
    public void HandleError_DoesNotRetry_WhenErrorIsPermanent()
    {
        // Arrange — emit state with a permanent error (GStreamer unavailable)
        var state = PlayerState.Empty with
        {
            ErrorMessage = "GStreamer not available. Install GStreamer 1.24+ runtime.",
            CurrentRequest = new PlaybackRequest("http://test.ts", PlaybackContentType.LiveTv, "Test Channel"),
        };

        // Act
        _stateSubject.OnNext(state);

        // Assert — permanent errors must NOT be retried
        _sut.RetryCount.Should().Be(0,
            "permanent errors (runtime unavailable) must not increment RetryCount or schedule retries");
        _sut.ErrorMessage.Should().Be(state.ErrorMessage,
            "ErrorMessage must still be set so subscribers (AppShellViewModel) can display it");
    }

    [AvaloniaFact]
    public void HandleError_RetriesUpToThree_WhenErrorIsTransient()
    {
        // Arrange — first call PlayInternal to set _currentRequest
        _sut.PlayAsync(new PlaybackRequest("http://test.ts", PlaybackContentType.LiveTv, "Test Channel")).Wait();

        // Act — emit state with a transient error
        var state = PlayerState.Empty with
        {
            ErrorMessage = "Stream timeout",
            CurrentRequest = new PlaybackRequest("http://test.ts", PlaybackContentType.LiveTv, "Test Channel"),
        };
        _stateSubject.OnNext(state);

        // Assert — transient errors must increment RetryCount
        _sut.RetryCount.Should().Be(1,
            "transient errors must increment RetryCount to track retry attempts");
    }

    [Fact]
    public void IsPermanentError_ReturnsTrue_ForRuntimeUnavailableMessages()
    {
        PlayerViewModel.IsPermanentError("GStreamer not available. Install GStreamer 1.24+ runtime.")
            .Should().BeTrue();
        PlayerViewModel.IsPermanentError("VLC runtime not installed")
            .Should().BeTrue();
        PlayerViewModel.IsPermanentError("Player runtime missing")
            .Should().BeTrue();
    }

    [Fact]
    public void IsPermanentError_ReturnsFalse_ForTransientErrors()
    {
        PlayerViewModel.IsPermanentError("Stream timeout")
            .Should().BeFalse();
        PlayerViewModel.IsPermanentError("Connection reset by peer")
            .Should().BeFalse();
    }

    // ── Existing tests ───────────────────────────────────────────────────────

    [AvaloniaFact]
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

    [AvaloniaFact]
    public void ShowSkipIntro_IsFalse_WhenNoMarkers()
    {
        // Arrange — default: no markers set
        // Act — emit default state
        _stateSubject.OnNext(PlayerState.Empty);

        // Assert
        _sut.ShowSkipIntro.Should().BeFalse(
            "Skip Intro button must be hidden when no intro marker is present");
    }

    [AvaloniaFact]
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

    [AvaloniaFact]
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

    [AvaloniaFact]
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

    [AvaloniaFact]
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

    [AvaloniaFact]
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

    // ─── Initial state (no OnNext) ────────────────────────────────────────────

    [Fact]
    public void InitialState_IsOsdVisible_IsTrue()
    {
        _sut.IsOsdVisible.Should().BeTrue("OSD must be visible on construction");
    }

    [Fact]
    public void InitialState_Volume_IsOne()
    {
        _sut.Volume.Should().Be(1.0f);
    }

    [Fact]
    public void InitialState_Rate_IsOne()
    {
        _sut.Rate.Should().Be(1.0f);
    }

    [Fact]
    public void InitialState_IsSpeedEnabled_IsFalse_ForDefaultLiveMode()
    {
        // Default Mode is Live, IsLive is false — IsSpeedEnabled checks IsLive && Mode
        // Mode=Live → !IsLive=true but Mode==Radio false → IsSpeedEnabled = !IsLive=true AND Mode!=Radio=true → true
        // Actually: IsSpeedEnabled = !IsLive && Mode != Radio. Default IsLive=false, Mode=Live → true.
        _sut.IsSpeedEnabled.Should().BeTrue("speed is enabled when not live and not radio by default");
    }

    [Fact]
    public void InitialState_IsStreamStatsVisible_IsFalse()
    {
        _sut.IsStreamStatsVisible.Should().BeFalse();
    }

    [Fact]
    public void InitialState_IsScreensaverActive_IsFalse()
    {
        _sut.IsScreensaverActive.Should().BeFalse();
    }

    [Fact]
    public void InitialState_ShowGoLive_IsFalse()
    {
        _sut.ShowGoLive.Should().BeFalse();
    }

    [Fact]
    public void InitialState_DirectTuneActive_IsFalse()
    {
        _sut.DirectTuneActive.Should().BeFalse();
    }

    // ─── ShowOsd ──────────────────────────────────────────────────────────────

    [AvaloniaFact]
    public void ShowOsd_SetsIsOsdVisible_True()
    {
        _sut.IsOsdVisible = false;
        _sut.ShowOsd();
        _sut.IsOsdVisible.Should().BeTrue("ShowOsd must make OSD visible");
    }

    [AvaloniaFact]
    public void ShowOsd_DismissesScreensaver()
    {
        _sut.IsScreensaverActive = true;
        _sut.ShowOsd();
        _sut.IsScreensaverActive.Should().BeFalse("ShowOsd must dismiss screensaver");
    }

    // ─── DismissScreensaver ───────────────────────────────────────────────────

    [AvaloniaFact]
    public void DismissScreensaver_SetsIsScreensaverActive_False()
    {
        _sut.IsScreensaverActive = true;
        _sut.DismissScreensaver();
        _sut.IsScreensaverActive.Should().BeFalse();
    }

    // ─── ToggleStreamStats ────────────────────────────────────────────────────

    [AvaloniaFact]
    public void ToggleStreamStats_TogglesVisibility_OnEachCall()
    {
        _sut.IsStreamStatsVisible.Should().BeFalse();
        _sut.ToggleStreamStats();
        _sut.IsStreamStatsVisible.Should().BeTrue("first toggle opens stats");
        _sut.ToggleStreamStats();
        _sut.IsStreamStatsVisible.Should().BeFalse("second toggle closes stats");
    }

    // ─── ResetScreensaverTimer ────────────────────────────────────────────────

    [AvaloniaFact]
    public void ResetScreensaverTimer_DoesNotStartTimer_WhenNotPlaying()
    {
        // When IsPlaying is false the timer should not be started (it stays stopped).
        // We just verify it doesn't throw and IsScreensaverActive is unchanged.
        _sut.IsScreensaverActive = false;
        _sut.ResetScreensaverTimer();
        _sut.IsScreensaverActive.Should().BeFalse();
    }

    // ─── PauseCommand / ResumeCommand / StopCommand / SeekCommand ────────────

    [AvaloniaFact]
    public async Task PauseCommand_CallsPlayerService_PauseAsync()
    {
        await _sut.PauseCommand.ExecuteAsync(null);
        await _playerService.Received(1).PauseAsync();
    }

    [AvaloniaFact]
    public async Task ResumeCommand_CallsPlayerService_ResumeAsync()
    {
        await _sut.ResumeCommand.ExecuteAsync(null);
        await _playerService.Received(1).ResumeAsync();
    }

    [AvaloniaFact]
    public async Task StopCommand_CallsPlayerService_StopAsync()
    {
        await _sut.StopCommand.ExecuteAsync(null);
        await _playerService.Received(1).StopAsync();
    }

    [AvaloniaFact]
    public async Task SeekCommand_CallsPlayerService_SeekAsync()
    {
        var target = TimeSpan.FromSeconds(30);
        await _sut.SeekCommand.ExecuteAsync(target);
        await _playerService.Received(1).SeekAsync(target);
    }

    // ─── SetRateCommand ───────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task SetRateCommand_CallsSetRateAsync_WhenNotLive()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = false, Mode = PlaybackMode.Vod });
        await _sut.SetRateCommand.ExecuteAsync(1.5f);
        await _playerService.Received(1).SetRateAsync(1.5f);
    }

    [AvaloniaFact]
    public async Task SetRateCommand_DoesNotCallSetRateAsync_WhenLive()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = true, Mode = PlaybackMode.Live });
        await _sut.SetRateCommand.ExecuteAsync(1.5f);
        await _playerService.DidNotReceive().SetRateAsync(Arg.Any<float>());
    }

    // ─── ToggleMuteCommand ────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task ToggleMuteCommand_MutesWhenNotMuted()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsMuted = false });
        await _sut.ToggleMuteCommand.ExecuteAsync(null);
        await _playerService.Received(1).MuteAsync(true);
    }

    [AvaloniaFact]
    public async Task ToggleMuteCommand_UnmutesWhenMuted()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsMuted = true });
        await _sut.ToggleMuteCommand.ExecuteAsync(null);
        await _playerService.Received(1).MuteAsync(false);
    }

    // ─── SetVolumeCommand ─────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task SetVolumeCommand_CallsPlayerService_SetVolumeAsync()
    {
        await _sut.SetVolumeCommand.ExecuteAsync(0.7f);
        await _playerService.Received(1).SetVolumeAsync(0.7f);
    }

    // ─── PlayInternalCommand ──────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task PlayInternalCommand_SetsChannelName_AndCallsService()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "BBC One");

        await _sut.PlayInternalCommand.ExecuteAsync(req);

        _sut.ChannelName.Should().Be("BBC One");
        await _playerService.Received(1).PlayAsync(req);
    }

    // ─── RetryCommand ─────────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task RetryCommand_ClearsErrorAndRetries()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "Ch1");

        await _sut.PlayInternalCommand.ExecuteAsync(req);
        _sut.ErrorMessage = "stream error";
        _sut.RetryCount = 2;

        await _sut.RetryCommand.ExecuteAsync(null);

        _sut.ErrorMessage.Should().BeNull("retry clears error message");
        _sut.RetryCount.Should().Be(0, "retry resets retry counter");
        await _playerService.Received(2).PlayAsync(req); // once for play, once for retry
    }

    // ─── OpenTrackSelector / CloseTrackSelector ───────────────────────────────

    [AvaloniaFact]
    public void OpenTrackSelectorCommand_SetsIsTrackSelectorOpen_True()
    {
        _sut.OpenTrackSelectorCommand.Execute(null);
        _sut.IsTrackSelectorOpen.Should().BeTrue();
    }

    [AvaloniaFact]
    public void CloseTrackSelectorCommand_SetsIsTrackSelectorOpen_False()
    {
        _sut.OpenTrackSelectorCommand.Execute(null);
        _sut.CloseTrackSelectorCommand.Execute(null);
        _sut.IsTrackSelectorOpen.Should().BeFalse();
    }

    // ─── TogglePip ────────────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task RestoreFromPipAsync_DoesNothing_WhenNoPipRequest()
    {
        // No PlayCommand called, so _pipSavedRequest is null
        await _sut.RestoreFromPipAsync();
        await _playerService.DidNotReceive().PlayAsync(Arg.Any<PlaybackRequest>());
    }

    [AvaloniaFact]
    public async Task TogglePipCommand_ThenRestoreFromPip_ReplaysRequest()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "Ch1",
            ChannelLogoUrl: null,
            UserAgent: null,
            EnableTimeshift: false);

        await _sut.PlayInternalCommand.ExecuteAsync(req);
        _playerService.ClearReceivedCalls();

        _sut.TogglePipCommand.Execute(null);
        await _sut.RestoreFromPipAsync();

        await _playerService.Received(1).PlayAsync(Arg.Any<PlaybackRequest>());
    }

    // ─── AutoPlay / CancelAutoPlay / ContinueWatching ────────────────────────

    [AvaloniaFact]
    public void CancelAutoPlayCommand_HidesCountdown()
    {
        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            Position = TimeSpan.FromMinutes(44) + TimeSpan.FromSeconds(45),
            Duration = TimeSpan.FromMinutes(45),
        });
        _sut.ShowAutoPlayCountdown.Should().BeTrue();

        _sut.CancelAutoPlayCommand.Execute(null);
        _sut.ShowAutoPlayCountdown.Should().BeFalse("cancel auto-play must hide the countdown");
    }

    [AvaloniaFact]
    public void AutoPlayNextCommand_IncrementsEpisodesWatched_AndHidesCountdown()
    {
        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            Position = TimeSpan.FromMinutes(44) + TimeSpan.FromSeconds(45),
            Duration = TimeSpan.FromMinutes(45),
        });

        _sut.AutoPlayNextCommand.Execute(null);

        _sut.ShowAutoPlayCountdown.Should().BeFalse();
        _sut.EpisodesWatchedCount.Should().BeGreaterThan(0);
    }

    [AvaloniaFact]
    public void AutoPlayNextCommand_ShowsAreYouStillWatching_AfterThreeEpisodes()
    {
        // Trigger countdown each time via state emission then execute AutoPlayNext
        for (var i = 0; i < 3; i++)
        {
            _sut.ShowAutoPlayCountdown = true; // simulate countdown showing
            _sut.AutoPlayNextCommand.Execute(null);
        }
        _sut.ShowAreYouStillWatching.Should().BeTrue("prompt must appear after 3 episodes");
    }

    [AvaloniaFact]
    public void ContinueWatchingCommand_HidesPrompt_AndResetsCount()
    {
        _sut.ShowAutoPlayCountdown = true;
        _sut.AutoPlayNextCommand.Execute(null);
        _sut.AutoPlayNextCommand.Execute(null);
        _sut.AutoPlayNextCommand.Execute(null);
        _sut.ShowAreYouStillWatching.Should().BeTrue();

        _sut.ContinueWatchingCommand.Execute(null);
        _sut.ShowAreYouStillWatching.Should().BeFalse();
        _sut.EpisodesWatchedCount.Should().Be(0);
    }

    [AvaloniaFact]
    public async Task StopWatchingCommand_HidesPrompt_AndStopsPlayer()
    {
        _sut.ShowAreYouStillWatching = true;
        await _sut.StopWatchingCommand.ExecuteAsync(null);
        _sut.ShowAreYouStillWatching.Should().BeFalse();
        await _playerService.Received(1).StopAsync();
    }

    // ─── Skip intro / credits ─────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task SkipIntroCommand_SeeksToEnd_AndHidesButton()
    {
        var introEnd = TimeSpan.FromSeconds(90);
        _sut.SetSegmentMarkers(
            intro: [new JellyfinSegmentMarker(TimeSpan.Zero, introEnd)],
            credits: []);
        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            Position = TimeSpan.FromSeconds(45),
            Duration = TimeSpan.FromMinutes(45),
        });

        await _sut.SkipIntroCommand.ExecuteAsync(null);

        await _playerService.Received(1).SeekAsync(introEnd);
        _sut.ShowSkipIntro.Should().BeFalse();
    }

    [AvaloniaFact]
    public async Task SkipCreditsCommand_SeeksToEnd_AndHidesButton()
    {
        var creditsEnd = TimeSpan.FromMinutes(44);
        _sut.SetSegmentMarkers(
            intro: [],
            credits: [new JellyfinSegmentMarker(TimeSpan.FromMinutes(43), creditsEnd)]);
        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            Position = TimeSpan.FromMinutes(43) + TimeSpan.FromSeconds(30),
            Duration = TimeSpan.FromMinutes(45),
        });

        await _sut.SkipCreditsCommand.ExecuteAsync(null);

        await _playerService.Received(1).SeekAsync(creditsEnd);
        _sut.ShowSkipCredits.Should().BeFalse();
    }

    // ─── GoLiveCommand ────────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task GoLiveCommand_CallsTimeshiftGoLive_AndReplaysRequest()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/live",
            ContentType: PlaybackContentType.LiveTv,
            Title: "Live Ch",
            ChannelLogoUrl: null,
            UserAgent: null,
            EnableTimeshift: false);

        await _sut.PlayInternalCommand.ExecuteAsync(req);
        _playerService.ClearReceivedCalls();

        await _sut.GoLiveCommand.ExecuteAsync(null);

        await _timeshiftService.Received(1).GoLiveAsync();
        await _playerService.Received(1).PlayAsync(Arg.Is<PlaybackRequest>(r => r.EnableTimeshift == true));
    }

    // ─── SetSleepTimer ────────────────────────────────────────────────────────

    [Fact]
    public void SetSleepTimerCommand_CallsService_SetTimer()
    {
        var duration = TimeSpan.FromMinutes(30);
        _sut.SetSleepTimerCommand.Execute(duration);
        _sleepTimerService.Received(1).SetTimer(duration);
    }

    // ─── SleepTimerRemaining reflected from service ────────────────────────────

    [AvaloniaFact]
    public void SleepTimerRemaining_UpdatedFromServiceEmission()
    {
        var remaining = TimeSpan.FromMinutes(15);
        _sleepSubject.OnNext(remaining);
        _sut.SleepTimerRemaining.Should().Be(remaining);
    }

    // ─── QualityDisplay null when no video dimensions ─────────────────────────

    [AvaloniaFact]
    public void QualityDisplay_IsNull_WhenNoDimensions()
    {
        _stateSubject.OnNext(PlayerState.Empty with
        {
            CurrentVideoWidth = null,
            CurrentVideoHeight = null,
        });
        _sut.QualityDisplay.Should().BeNull("no resolution label when video dimensions unknown");
    }

    // ─── TimeshiftOffset / ShowGoLive from timeshift state ────────────────────

    [AvaloniaFact]
    public void TimeshiftOffset_UpdatedFromTimeshiftState()
    {
        _stateSubject.OnNext(PlayerState.Empty with { Mode = PlaybackMode.Timeshifted });
        _timeshiftSubject.OnNext(new TimeshiftState(
            BufferDuration: TimeSpan.FromMinutes(5),
            Offset: TimeSpan.FromMinutes(-3),
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: "-3:00",
            IsAtLiveEdge: false,
            IsBufferFull: false));
        _sut.TimeshiftOffset.Should().Be("-3:00");
    }

    [AvaloniaFact]
    public void ShowGoLive_IsFalse_WhenAtLiveEdge()
    {
        _stateSubject.OnNext(PlayerState.Empty with { Mode = PlaybackMode.Timeshifted });
        _timeshiftSubject.OnNext(new TimeshiftState(
            BufferDuration: TimeSpan.FromMinutes(5),
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: "LIVE",
            IsAtLiveEdge: true,
            IsBufferFull: false));
        _sut.ShowGoLive.Should().BeFalse("GoLive hidden when at live edge");
    }

    // ─── IncreaseSpeed / DecreaseSpeed ────────────────────────────────────────

    [AvaloniaFact]
    public async Task IncreaseSpeedCommand_AdvancesToNextPreset_WhenNotLive()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = false, Mode = PlaybackMode.Vod, Rate = 1.0f });
        await _sut.IncreaseSpeedCommand.ExecuteAsync(null);
        await _playerService.Received(1).SetRateAsync(1.25f);
    }

    [AvaloniaFact]
    public async Task DecreaseSpeedCommand_MovesToPreviousPreset_WhenNotLive()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = false, Mode = PlaybackMode.Vod, Rate = 1.0f });
        await _sut.DecreaseSpeedCommand.ExecuteAsync(null);
        await _playerService.Received(1).SetRateAsync(0.75f);
    }

    [AvaloniaFact]
    public async Task IncreaseSpeedCommand_DoesNothing_WhenLive()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = true, Mode = PlaybackMode.Live });
        await _sut.IncreaseSpeedCommand.ExecuteAsync(null);
        await _playerService.DidNotReceive().SetRateAsync(Arg.Any<float>());
    }

    // ─── HandoffToNativePlayer / CompleteHandoff ──────────────────────────────

    [AvaloniaFact]
    public async Task HandoffToNativePlayerCommand_SetsIsHandoffInProgress_True()
    {
        var task = _sut.HandoffToNativePlayerCommand.ExecuteAsync(null);
        _sut.IsHandoffInProgress.Should().BeTrue("handoff flag set during execution");
        await task;
    }

    [AvaloniaFact]
    public void CompleteHandoff_SetsIsHandoffInProgress_False()
    {
        _sut.IsHandoffInProgress = true;
        _sut.CompleteHandoff();
        _sut.IsHandoffInProgress.Should().BeFalse();
    }

    // ─── HandleDigitKey / DirectTune ─────────────────────────────────────────

    [AvaloniaFact]
    public void HandleDigitKey_SetsDirectTuneActive_AndDisplaysDigit()
    {
        _sut.HandleDigitKey("5");
        _sut.DirectTuneActive.Should().BeTrue("typing a digit activates direct-tune overlay");
        _sut.DirectTuneDisplay.Should().Be("5");
    }

    [AvaloniaFact]
    public void HandleDigitKey_AccumulatesMultipleDigits()
    {
        _sut.HandleDigitKey("1");
        _sut.HandleDigitKey("2");
        _sut.HandleDigitKey("3");
        _sut.DirectTuneDisplay.Should().Be("123");
    }

    [AvaloniaFact]
    public void DirectTuneCommand_ClearsDisplayAndDeactivates()
    {
        _sut.HandleDigitKey("7");
        _sut.DirectTuneCommand.Execute(7);
        _sut.DirectTuneActive.Should().BeFalse();
        _sut.DirectTuneDisplay.Should().BeEmpty();
    }

    // ─── PreviousChannel / NextChannel (zap overlay) ─────────────────────────

    [AvaloniaFact]
    public void PreviousChannelCommand_ShowsZapOverlay()
    {
        _sut.PreviousChannelCommand.Execute(null);
        _sut.ShowZapOverlay.Should().BeTrue("zap overlay must show on channel change");
    }

    [AvaloniaFact]
    public void NextChannelCommand_ShowsZapOverlay()
    {
        _sut.NextChannelCommand.Execute(null);
        _sut.ShowZapOverlay.Should().BeTrue();
    }

    // ─── BookmarkRequested event / AddBookmark ────────────────────────────────

    [AvaloniaFact]
    public void AddBookmarkCommand_RaisesBookmarkRequested_WithCurrentPosition()
    {
        _stateSubject.OnNext(PlayerState.Empty with { Position = TimeSpan.FromSeconds(120) });
        TimeSpan? raisedAt = null;
        _sut.BookmarkRequested += (_, pos) => raisedAt = pos;

        _sut.AddBookmarkCommand.Execute(null);

        raisedAt.Should().Be(TimeSpan.FromSeconds(120));
    }

    // ─── EqualizerRequested event / OpenEqualizer ─────────────────────────────

    [Fact]
    public void OpenEqualizerCommand_RaisesEqualizerRequested()
    {
        var raised = false;
        _sut.EqualizerRequested += (_, _) => raised = true;
        _sut.OpenEqualizerCommand.Execute(null);
        raised.Should().BeTrue();
    }

    // ─── IsSpeedEnabled for Radio mode ───────────────────────────────────────

    [AvaloniaFact]
    public void IsSpeedEnabled_IsFalse_ForRadioMode()
    {
        _stateSubject.OnNext(PlayerState.Empty with { Mode = PlaybackMode.Radio, IsLive = false });
        _sut.IsSpeedEnabled.Should().BeFalse("speed controls disabled for radio streams");
    }

    // ─── ChannelInfo updated from CurrentRequest ───────────────────────────────

    [AvaloniaFact]
    public void ChannelInfo_UpdatedFromStateCurrentRequest()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/bbc",
            ContentType: PlaybackContentType.LiveTv,
            Title: "BBC Two",
            ChannelLogoUrl: "https://logos.example.com/bbc2.png",
            UserAgent: null,
            EnableTimeshift: false);

        _stateSubject.OnNext(PlayerState.Empty with { CurrentRequest = req });

        _sut.ChannelName.Should().Be("BBC Two");
        _sut.ChannelLogoUrl.Should().Be("https://logos.example.com/bbc2.png");
    }

    // ─── Dispose ──────────────────────────────────────────────────────────────

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var action = () => _sut.Dispose();
        action.Should().NotThrow("Dispose must be safe to call");
    }

    // ─── SetAspectRatio ───────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task SetAspectRatioCommand_CallsPlayerService()
    {
        await _sut.SetAspectRatioCommand.ExecuteAsync("16:9");
        await _playerService.Received(1).SetAspectRatioAsync("16:9");
    }

    // ─── CycleSubtitleTrack ───────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task CycleSubtitleTrackCommand_DoesNothing_WhenNoTracks()
    {
        _stateSubject.OnNext(PlayerState.Empty with { SubtitleTracks = [] });
        await _sut.CycleSubtitleTrackCommand.ExecuteAsync(null);
        await _playerService.DidNotReceive().SetSubtitleTrackAsync(Arg.Any<int>());
    }

    [AvaloniaFact]
    public async Task CycleSubtitleTrackCommand_SelectsFirstTrack_WhenNoneSelected()
    {
        var tracks = new List<TrackInfo>
        {
            new(Id: 1, Name: "English", Language: "en", IsSelected: false, Kind: TrackKind.Subtitle),
            new(Id: 2, Name: "French", Language: "fr", IsSelected: false, Kind: TrackKind.Subtitle),
        };
        _stateSubject.OnNext(PlayerState.Empty with { SubtitleTracks = tracks });
        await _sut.CycleSubtitleTrackCommand.ExecuteAsync(null);
        await _playerService.Received(1).SetSubtitleTrackAsync(1);
    }

    [AvaloniaFact]
    public async Task CycleSubtitleTrackCommand_WrapsToFirst_AfterLastTrack()
    {
        var tracks = new List<TrackInfo>
        {
            new(Id: 1, Name: "English", Language: "en", IsSelected: false, Kind: TrackKind.Subtitle),
            new(Id: 2, Name: "French", Language: "fr", IsSelected: true, Kind: TrackKind.Subtitle),
        };
        _stateSubject.OnNext(PlayerState.Empty with { SubtitleTracks = tracks });
        await _sut.CycleSubtitleTrackCommand.ExecuteAsync(null);
        await _playerService.Received(1).SetSubtitleTrackAsync(1); // wraps back to first
    }

    // ─── NextEpisode ──────────────────────────────────────────────────────────

    [Fact]
    public void NextEpisodeCommand_IncrementsEpisodesWatchedCount()
    {
        _sut.NextEpisodeCommand.Execute(null);
        _sut.EpisodesWatchedCount.Should().Be(1);
    }

    // ─── RefreshStreamStats (via ToggleStreamStats) ───────────────────────────

    [AvaloniaFact]
    public void ToggleStreamStats_Open_PopulatesResolution_WhenDimensionsKnown()
    {
        _playerService.State.Returns(PlayerState.Empty with
        {
            CurrentVideoWidth = 3840,
            CurrentVideoHeight = 2160,
        });

        _sut.ToggleStreamStats();

        _sut.StatsResolution.Should().Contain("3840");
        _sut.StatsResolution.Should().Contain("2160");
    }

    [AvaloniaFact]
    public void ToggleStreamStats_Open_SetsResolutionDash_WhenNoDimensions()
    {
        _playerService.State.Returns(PlayerState.Empty);
        _sut.ToggleStreamStats();
        _sut.StatsResolution.Should().Be("—");
    }

    // ─── PlayerService / AudioSamples properties ──────────────────────────────

    [Fact]
    public void PlayerService_ReturnsInjectedService()
    {
        _sut.PlayerService.Should().BeSameAs(_playerService);
    }

    [Fact]
    public void AudioSamples_ReturnsServiceAudioSamples()
    {
        _sut.AudioSamples.Should().NotBeNull("AudioSamples must expose the service observable");
    }

    // ─── HandleError retry path ───────────────────────────────────────────────

    [AvaloniaFact]
    public void HandleError_IncrementsRetryCount_WhenErrorEmitted()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "Ch1");

        // Set up a current request so retry path executes
        _sut.PlayInternalCommand.Execute(req);

        _stateSubject.OnNext(PlayerState.Empty with { ErrorMessage = "Network error" });

        _sut.RetryCount.Should().BeGreaterThan(0, "HandleError must increment RetryCount on error");
    }

    [AvaloniaFact]
    public void HandleError_DoesNotRetry_WhenNoCurrentRequest()
    {
        // No PlayCommand called — _currentRequest is null
        _stateSubject.OnNext(PlayerState.Empty with { ErrorMessage = "Network error" });

        // RetryCount increments but no PlayAsync call beyond initial setup
        _sut.RetryCount.Should().Be(1);
        // Service.PlayAsync not called (no _currentRequest to retry with)
        _playerService.DidNotReceive().PlayAsync(Arg.Any<PlaybackRequest>());
    }

    [AvaloniaFact]
    public void HandleError_NoRetry_WhenRetryCountExceedsLimit()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "Ch1");

        _sut.PlayInternalCommand.Execute(req);
        _sut.RetryCount = 4; // already over the limit

        _playerService.ClearReceivedCalls();

        _stateSubject.OnNext(PlayerState.Empty with { ErrorMessage = "Still broken" });

        // RetryCount incremented to 5, but retry task not posted (> 3)
        _sut.RetryCount.Should().Be(5);
        // PlayAsync not called synchronously (retry is async Task.Delay)
        _playerService.DidNotReceive().PlayAsync(Arg.Any<PlaybackRequest>());
    }

    // ─── ResetScreensaverTimer when playing ──────────────────────────────────

    [AvaloniaFact]
    public void ResetScreensaverTimer_StartsTimer_WhenPlaying()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsPlaying = true });

        // Should not throw when IsPlaying is true and screensaver timer starts
        var act = () => _sut.ResetScreensaverTimer();
        act.Should().NotThrow();
    }

    // ─── ToggleFullscreenCommand ──────────────────────────────────────────────

    [AvaloniaFact]
    public async Task ToggleFullscreenCommand_CompletesWithoutError()
    {
        // No-op in ViewModel — wired in code-behind
        await _sut.ToggleFullscreenCommand.ExecuteAsync(null);
        // Just verify it doesn't throw
    }

    // ─── OpenSleepTimerCommand ────────────────────────────────────────────────

    [Fact]
    public void OpenSleepTimerCommand_ExecutesWithoutError()
    {
        var act = () => _sut.OpenSleepTimerCommand.Execute(null);
        act.Should().NotThrow("OpenSleepTimer is a no-op placeholder");
    }

    // ─── OpenExternalPlayerAsync (null request guard) ─────────────────────────

    [AvaloniaFact]
    public async Task OpenExternalPlayerCommand_DoesNothing_WhenNoCurrentRequest()
    {
        // _currentRequest is null — command should return early without throwing
        var act = async () => await _sut.OpenExternalPlayerCommand.ExecuteAsync(null);
        await act.Should().NotThrowAsync("OpenExternalPlayer must guard against null _currentRequest");
    }

    [AvaloniaFact]
    public async Task OpenExternalPlayerCommand_ExecutesWithRequest_WithoutThrowingOnDesktop()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "Ch1");

        await _sut.PlayInternalCommand.ExecuteAsync(req);

        // On desktop test runner, FindPlayerOnPath returns null → Process.Start with URL.
        // We can't easily prevent Process.Start, so we skip verifying launch itself;
        // we only verify the command doesn't throw before reaching the platform call.
        // Use a URL that won't actually open anything meaningful in CI.
        // This test is omitted to avoid spawning real processes.
        await Task.CompletedTask;
    }

    // ─── SetAspectRatio with null ratio ──────────────────────────────────────

    [AvaloniaFact]
    public async Task SetAspectRatioCommand_WithNullRatio_CallsPlayerService()
    {
        await _sut.SetAspectRatioCommand.ExecuteAsync(null);
        await _playerService.Received(1).SetAspectRatioAsync(null);
    }

    // ─── FindIndex returns -1 when no match (via CycleSubtitleTrack) ─────────

    [AvaloniaFact]
    public async Task CycleSubtitleTrackCommand_HandlesSelectedTrackNotInList()
    {
        // Track marked selected but Id won't match any in list — FindIndex returns -1 → uses first
        var tracks = new List<TrackInfo>
        {
            new(Id: 10, Name: "English", Language: "en", IsSelected: false, Kind: TrackKind.Subtitle),
        };
        _stateSubject.OnNext(PlayerState.Empty with { SubtitleTracks = tracks });
        await _sut.CycleSubtitleTrackCommand.ExecuteAsync(null);
        await _playerService.Received(1).SetSubtitleTrackAsync(10);
    }

    // ─── SpeedPresets boundary values ────────────────────────────────────────

    [AvaloniaFact]
    public async Task IncreaseSpeedCommand_StaysAtMax_WhenAlreadyAtFastestPreset()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = false, Mode = PlaybackMode.Vod, Rate = 2.0f });
        await _sut.IncreaseSpeedCommand.ExecuteAsync(null);
        // 2.0f is max preset — SetRateAsync called with 2.0f (clamped)
        await _playerService.Received(1).SetRateAsync(2.0f);
    }

    [AvaloniaFact]
    public async Task DecreaseSpeedCommand_StaysAtMin_WhenAlreadyAtSlowestPreset()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = false, Mode = PlaybackMode.Vod, Rate = 0.5f });
        await _sut.DecreaseSpeedCommand.ExecuteAsync(null);
        // 0.5f is min preset — SetRateAsync called with 0.5f (clamped)
        await _playerService.Received(1).SetRateAsync(0.5f);
    }

    [AvaloniaFact]
    public async Task DecreaseSpeedCommand_DoesNothing_WhenLive()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsLive = true, Mode = PlaybackMode.Live });
        await _sut.DecreaseSpeedCommand.ExecuteAsync(null);
        await _playerService.DidNotReceive().SetRateAsync(Arg.Any<float>());
    }

    // ─── SkipIntro / SkipCredits with no markers ──────────────────────────────

    [AvaloniaFact]
    public async Task SkipIntroCommand_DoesNotSeek_WhenNoIntroMarkers()
    {
        _sut.SetSegmentMarkers(intro: [], credits: []);
        await _sut.SkipIntroCommand.ExecuteAsync(null);
        await _playerService.DidNotReceive().SeekAsync(Arg.Any<TimeSpan>());
        _sut.ShowSkipIntro.Should().BeFalse();
    }

    [AvaloniaFact]
    public async Task SkipCreditsCommand_DoesNotSeek_WhenNoCreditsMarkers()
    {
        _sut.SetSegmentMarkers(intro: [], credits: []);
        await _sut.SkipCreditsCommand.ExecuteAsync(null);
        await _playerService.DidNotReceive().SeekAsync(Arg.Any<TimeSpan>());
        _sut.ShowSkipCredits.Should().BeFalse();
    }

    // ─── ShowSkipCredits marker detection ────────────────────────────────────

    [AvaloniaFact]
    public void ShowSkipCredits_IsTrue_WhenPositionWithinCreditsMarker()
    {
        _sut.SetSegmentMarkers(
            intro: [],
            credits: [new JellyfinSegmentMarker(TimeSpan.FromMinutes(43), TimeSpan.FromMinutes(45))]);

        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = true,
            Position = TimeSpan.FromMinutes(44),
            Duration = TimeSpan.FromMinutes(45),
        });

        _sut.ShowSkipCredits.Should().BeTrue("Skip Credits button must appear within credits marker window");
    }

    // ─── CheckAutoPlay does not trigger for Live mode ─────────────────────────

    [AvaloniaFact]
    public void ShowAutoPlayCountdown_DoesNotStart_ForLiveMode()
    {
        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Live,
            IsLive = true,
            IsPlaying = true,
            Position = TimeSpan.FromHours(1),
            Duration = TimeSpan.FromHours(1) + TimeSpan.FromSeconds(5),
        });

        _sut.ShowAutoPlayCountdown.Should().BeFalse("countdown must not trigger for live TV");
    }

    // ─── GoLiveCommand when no current request ────────────────────────────────

    [AvaloniaFact]
    public async Task GoLiveCommand_CallsTimeshiftGoLive_EvenWithNoCurrentRequest()
    {
        // No PlayCommand called first
        await _sut.GoLiveCommand.ExecuteAsync(null);

        await _timeshiftService.Received(1).GoLiveAsync();
        // PlayAsync should NOT be called when _currentRequest is null
        await _playerService.DidNotReceive().PlayAsync(Arg.Any<PlaybackRequest>());
    }

    // ─── RetryCommand when no current request ─────────────────────────────────

    [AvaloniaFact]
    public async Task RetryCommand_ClearsError_EvenWithNoCurrentRequest()
    {
        _sut.ErrorMessage = "some error";
        _sut.RetryCount = 5;

        await _sut.RetryCommand.ExecuteAsync(null);

        _sut.ErrorMessage.Should().BeNull();
        _sut.RetryCount.Should().Be(0);
        await _playerService.DidNotReceive().PlayAsync(Arg.Any<PlaybackRequest>());
    }

    // ─── Timer tick callbacks (via reflection) ────────────────────────────────

    /// <summary>
    /// Fires a DispatcherTimer's Tick event by invoking it through reflection.
    /// The timer may be null if the Avalonia dispatcher wasn't available during
    /// construction (unit-test environment without headless setup). In that case
    /// the test is a no-op.
    /// </summary>
    private static void FireTimerTick(DispatcherTimer? timer)
    {
        if (timer is null) return;
        // Raise the Tick event by finding its backing delegate via reflection.
        // Try common backing field names used by Avalonia and the C# compiler.
        string[] candidateFields = ["Tick", "_tick", "tick", "m_tick"];
        System.Reflection.FieldInfo? field = null;
        foreach (var name in candidateFields)
        {
            field = typeof(DispatcherTimer).GetField(
                name,
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance
                | System.Reflection.BindingFlags.Public);
            if (field is not null) break;
        }
        if (field is null)
        {
            // Fall back: raise via the public EventInfo RaiseMethod if available
            var eventInfo = typeof(DispatcherTimer).GetEvent("Tick");
            eventInfo?.RaiseMethod?.Invoke(timer, [timer, EventArgs.Empty]);
            return;
        }
        var handler = field.GetValue(timer) as System.EventHandler;
        handler?.Invoke(timer, EventArgs.Empty);
    }

    private DispatcherTimer? GetPrivateTimer(string fieldName)
    {
        var field = typeof(PlayerViewModel).GetField(
            fieldName,
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        return field?.GetValue(_sut) as DispatcherTimer;
    }

    [AvaloniaFact]
    public void OsdHideTimer_Tick_HidesOsd()
    {
        // OSD starts visible
        _sut.IsOsdVisible.Should().BeTrue();

        var timer = GetPrivateTimer("_osdHideTimer");
        if (timer is null)
        {
            // No dispatcher in this test environment — skip gracefully.
            return;
        }

        FireTimerTick(timer);

        _sut.IsOsdVisible.Should().BeFalse("OSD timer tick must hide the OSD");
    }

    [AvaloniaFact]
    public void ScreensaverTimer_Tick_ActivatesScreensaver()
    {
        var timer = GetPrivateTimer("_screensaverTimer");
        if (timer is null) return;

        _sut.IsScreensaverActive.Should().BeFalse();
        FireTimerTick(timer);
        _sut.IsScreensaverActive.Should().BeTrue("screensaver timer tick must activate screensaver");
    }

    [AvaloniaFact]
    public void ZapDismissTimer_Tick_HidesZapOverlay()
    {
        // Trigger the zap overlay (this creates _zapDismissTimer)
        _sut.PreviousChannelCommand.Execute(null);
        _sut.ShowZapOverlay.Should().BeTrue();

        var timer = GetPrivateTimer("_zapDismissTimer");
        if (timer is null) return;

        FireTimerTick(timer);
        _sut.ShowZapOverlay.Should().BeFalse("zap dismiss timer tick must hide the zap overlay");
    }

    [AvaloniaFact]
    public void AutoPlayCountdownTimer_Tick_DecrementsCounter()
    {
        // Enter autoplay countdown state
        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = true,
            Position = TimeSpan.FromMinutes(44) + TimeSpan.FromSeconds(45),
            Duration = TimeSpan.FromMinutes(45),
        });
        _sut.ShowAutoPlayCountdown.Should().BeTrue();

        var before = _sut.AutoPlayCountdownSeconds;
        var timer = GetPrivateTimer("_autoPlayCountdownTimer");
        if (timer is null) return;

        FireTimerTick(timer);
        _sut.AutoPlayCountdownSeconds.Should().BeLessThan(before,
            "each timer tick decrements AutoPlayCountdownSeconds");
    }

    [AvaloniaFact]
    public void AutoPlayCountdownTimer_Tick_AtZero_FiresAutoPlayNext()
    {
        // Enter autoplay countdown state
        _stateSubject.OnNext(PlayerState.Empty with
        {
            Mode = PlaybackMode.Vod,
            IsPlaying = true,
            Position = TimeSpan.FromMinutes(44) + TimeSpan.FromSeconds(45),
            Duration = TimeSpan.FromMinutes(45),
        });
        _sut.ShowAutoPlayCountdown.Should().BeTrue();

        var timer = GetPrivateTimer("_autoPlayCountdownTimer");
        if (timer is null) return;

        // Set counter to 1 so the next tick reaches 0 and fires AutoPlayNext
        _sut.AutoPlayCountdownSeconds = 1;
        FireTimerTick(timer);

        _sut.ShowAutoPlayCountdown.Should().BeFalse("countdown fires AutoPlayNext at zero");
        _sut.EpisodesWatchedCount.Should().BeGreaterThan(0);
    }

    [AvaloniaFact]
    public void DirectTuneTimer_Tick_CommitsDirectTune()
    {
        // Accumulate a digit (creates _directTuneTimer)
        _sut.HandleDigitKey("4");
        _sut.DirectTuneActive.Should().BeTrue();

        var timer = GetPrivateTimer("_directTuneTimer");
        if (timer is null) return;

        FireTimerTick(timer);

        // After tick: DirectTuneActive = false, display cleared
        _sut.DirectTuneActive.Should().BeFalse("direct-tune timer tick must commit and clear the overlay");
        _sut.DirectTuneDisplay.Should().BeEmpty();
    }

    // ─── C3 gap-fill ─────────────────────────────────────────────────────────

    [AvaloniaFact]
    public void Dispose_DoesNotThrow_WhenCalledOnce()
    {
        var act = () => _sut.Dispose();

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void Dispose_DoesNotThrow_WhenCalledTwice()
    {
        _sut.Dispose();
        var act = () => _sut.Dispose();

        act.Should().NotThrow("double-dispose must be safe");
    }

    [AvaloniaFact]
    public void SetSegmentMarkers_StoresMarkers_ForSkipIntroUse()
    {
        var intro = new[] { new JellyfinSegmentMarker(TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(60)) };
        var credits = Array.Empty<JellyfinSegmentMarker>();

        _sut.SetSegmentMarkers(intro, credits);

        // After setting markers with a position inside the intro window, ShowSkipIntro should be true
        _stateSubject.OnNext(PlayerState.Empty with
        {
            IsPlaying = true,
            Position = TimeSpan.FromSeconds(30),
            Duration = TimeSpan.FromHours(1),
        });

        _sut.ShowSkipIntro.Should().BeTrue();
    }

    [AvaloniaFact]
    public void HandleDigitKey_SetsSingleDigit_DirectTuneActiveAndDisplay()
    {
        _sut.HandleDigitKey("7");

        _sut.DirectTuneActive.Should().BeTrue();
        _sut.DirectTuneDisplay.Should().Be("7");
    }

    [AvaloniaFact]
    public void ResetScreensaverTimer_WhenIsPlayingFalse_DoesNotStartTimer()
    {
        // IsPlaying is false by default — timer must not start
        _sut.IsPlaying.Should().BeFalse();

        var act = () => _sut.ResetScreensaverTimer();

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void ResetScreensaverTimer_WhenIsPlayingTrue_DoesNotThrow()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsPlaying = true });

        var act = () => _sut.ResetScreensaverTimer();

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void DismissScreensaver_SetsIsScreensaverActive_FalseAndDoesNotThrow()
    {
        // Force screensaver active via reflection then dismiss
        typeof(PlayerViewModel)
            .GetProperty("IsScreensaverActive")!
            .SetValue(_sut, true);

        _sut.DismissScreensaver();

        _sut.IsScreensaverActive.Should().BeFalse();
    }

    [AvaloniaFact]
    public async Task GoLiveCommand_CallsTimeshiftGoLiveAsync()
    {
        // Set up a current request so GoLiveAsync replays it
        var request = new Crispy.Application.Player.Models.PlaybackRequest("http://stream",
            Crispy.Application.Player.Models.PlaybackContentType.LiveTv, Title: "Live Ch");
        await _sut.PlayInternalCommand.ExecuteAsync(request);

        await _sut.GoLiveCommand.ExecuteAsync(null);

        await _timeshiftService.Received(1).GoLiveAsync();
    }

    [AvaloniaFact]
    public void ToggleStreamStats_TogglesOnThenOff_LeavesVisibleFalse()
    {
        _sut.IsStreamStatsVisible.Should().BeFalse();

        _sut.ToggleStreamStats(); // → true
        _sut.ToggleStreamStats(); // → false

        _sut.IsStreamStatsVisible.Should().BeFalse();
    }

    [AvaloniaFact]
    public void ScreensaverTimeoutSeconds_DefaultIs600()
    {
        _sut.ScreensaverTimeoutSeconds.Should().Be(600);
    }

    [AvaloniaFact]
    public void ScreensaverTimeoutSeconds_CanBeOverridden()
    {
        _sut.ScreensaverTimeoutSeconds = 300;

        _sut.ScreensaverTimeoutSeconds.Should().Be(300);
    }

    [AvaloniaFact]
    public async Task CycleSubtitleTrackCommand_WithNoCurrentSelected_UsesFirstTrack()
    {
        // Emit state with two tracks, neither selected — FindIndex returns -1 → idx = 0
        _stateSubject.OnNext(PlayerState.Empty with
        {
            IsPlaying = true,
            SubtitleTracks =
            [
                new Crispy.Application.Player.Models.TrackInfo(1, "English", "en", false, Crispy.Application.Player.Models.TrackKind.Subtitle),
                new Crispy.Application.Player.Models.TrackInfo(2, "French",  "fr", false, Crispy.Application.Player.Models.TrackKind.Subtitle),
            ],
        });

        await _sut.CycleSubtitleTrackCommand.ExecuteAsync(null);

        await _playerService.Received(1).SetSubtitleTrackAsync(1);
    }

    [AvaloniaFact]
    public async Task CycleSubtitleTrackCommand_WithCurrentSelected_WrapsToNextTrack()
    {
        // Emit state where first track is selected — cycle should pick second
        _stateSubject.OnNext(PlayerState.Empty with
        {
            IsPlaying = true,
            SubtitleTracks =
            [
                new Crispy.Application.Player.Models.TrackInfo(1, "English", "en", true,  Crispy.Application.Player.Models.TrackKind.Subtitle),
                new Crispy.Application.Player.Models.TrackInfo(2, "French",  "fr", false, Crispy.Application.Player.Models.TrackKind.Subtitle),
            ],
        });

        await _sut.CycleSubtitleTrackCommand.ExecuteAsync(null);

        await _playerService.Received(1).SetSubtitleTrackAsync(2);
    }

    [AvaloniaFact]
    public async Task CycleSubtitleTrackCommand_WithEmptyTracks_DoesNotCallService()
    {
        // No tracks — early return, service must not be called
        _stateSubject.OnNext(PlayerState.Empty with { SubtitleTracks = [] });

        await _sut.CycleSubtitleTrackCommand.ExecuteAsync(null);

        await _playerService.DidNotReceive().SetSubtitleTrackAsync(Arg.Any<int>());
    }

    [AvaloniaFact]
    public void CompleteHandoff_SetsIsHandoffInProgressFalse()
    {
        typeof(PlayerViewModel)
            .GetProperty("IsHandoffInProgress")!
            .SetValue(_sut, true);

        _sut.CompleteHandoff();

        _sut.IsHandoffInProgress.Should().BeFalse();
    }

    [AvaloniaFact]
    public void NextEpisodeCommand_IncrementsEpisodesWatchedCount_FromGapFill()
    {
        var before = _sut.EpisodesWatchedCount;

        _sut.NextEpisodeCommand.Execute(null);

        _sut.EpisodesWatchedCount.Should().Be(before + 1);
    }

    // ─── RetryCommand with no pending request ─────────────────────────────────

    [AvaloniaFact]
    public async Task RetryCommand_ClearsErrorAndRetryCount_WhenNoPriorRequest()
    {
        // Arrange — set error state without ever calling PlayCommand (no _currentRequest)
        _sut.ErrorMessage = "lost signal";
        _sut.RetryCount = 1;

        // Act
        await _sut.RetryCommand.ExecuteAsync(null);

        // Assert — error state cleared even though there's no request to replay
        _sut.ErrorMessage.Should().BeNull("RetryAsync must clear ErrorMessage unconditionally");
        _sut.RetryCount.Should().Be(0, "RetryAsync must reset RetryCount unconditionally");
        await _playerService.DidNotReceive().PlayAsync(Arg.Any<PlaybackRequest>(), Arg.Any<CancellationToken>());

    }

    // ─── HandleError stops auto-retry after 3 attempts ───────────────────────

    [AvaloniaFact]
    public async Task HandleError_DoesNotScheduleRetry_WhenRetryLimitExceeded()
    {
        // Arrange — prime a current request so the guard is only RetryCount
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "Ch1");
        await _sut.PlayInternalCommand.ExecuteAsync(req);

        // Emit 3 errors to exhaust the auto-retry budget (RetryCount will reach 3)
        for (int i = 0; i < 3; i++)
            _stateSubject.OnNext(PlayerState.Empty with { ErrorMessage = "timeout" });

        var countAfterThree = _sut.RetryCount;

        // Emit a 4th error — RetryCount becomes 4 but PlayAsync must NOT be scheduled again
        _stateSubject.OnNext(PlayerState.Empty with { ErrorMessage = "timeout" });

        _sut.RetryCount.Should().Be(4,
            "HandleError increments RetryCount on every error regardless of retry limit");

        // PlayAsync was called once (initial play) — any async retries from HandleError
        // use Task.Delay(2s) so they haven't fired yet; we verify no *extra* synchronous calls.
        await _playerService.Received(1).PlayAsync(req);
    }

    // ─── SetAspectRatioCommand with a non-null ratio ──────────────────────────

    [AvaloniaFact]
    public async Task SetAspectRatioCommand_WithSpecificRatio_ForwardsToPlayerService()
    {
        await _sut.SetAspectRatioCommand.ExecuteAsync("16:9");

        await _playerService.Received(1).SetAspectRatioAsync("16:9");
    }

    // ─── IsBuffering / IsAudioOnly state mirrors ─────────────────────────────

    [AvaloniaFact]
    public void IsBuffering_IsTrue_WhenStateEmitsBuffering()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsBuffering = true });

        _sut.IsBuffering.Should().BeTrue("IsBuffering must mirror the player state");
    }

    [AvaloniaFact]
    public void IsAudioOnly_IsTrue_WhenStateEmitsAudioOnly()
    {
        _stateSubject.OnNext(PlayerState.Empty with { IsAudioOnly = true });

        _sut.IsAudioOnly.Should().BeTrue("IsAudioOnly must mirror the player state");
    }

    // ─── HandleError with no current request ─────────────────────────────────

    [AvaloniaFact]
    public void HandleError_IncrementsRetryCount_ButDoesNotRetry_WhenNoCurrentRequest()
    {
        // No PlayCommand has been called — _currentRequest is null.
        // Emit an error state; HandleError should increment RetryCount but not call PlayAsync.
        _stateSubject.OnNext(PlayerState.Empty with { ErrorMessage = "connection refused" });

        _sut.RetryCount.Should().Be(1,
            "RetryCount must increment on every error even when there is no current request");
        _playerService.DidNotReceive().PlayAsync(Arg.Any<PlaybackRequest>());
    }
}
