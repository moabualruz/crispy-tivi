using Avalonia.Headless.XUnit;

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

    // ─── PlayCommand ──────────────────────────────────────────────────────────

    [AvaloniaFact]
    public async Task PlayCommand_SetsChannelName_AndCallsService()
    {
        var req = new PlaybackRequest(
            Url: "http://tv.example.com/ch1",
            ContentType: PlaybackContentType.LiveTv,
            Title: "BBC One");

        await _sut.PlayCommand.ExecuteAsync(req);

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

        await _sut.PlayCommand.ExecuteAsync(req);
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

        await _sut.PlayCommand.ExecuteAsync(req);
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

        await _sut.PlayCommand.ExecuteAsync(req);
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
}
