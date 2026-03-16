using System.Collections.ObjectModel;
using System.Diagnostics;

using Avalonia.Threading;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Navigation;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the full-screen player OSD.
/// Manages playback state, commands, track lists, screensaver, stream stats,
/// keyboard/gesture routing, external player launch, and PiP restore.
/// OSD display state (channel info, visibility, skip markers, auto-play) is
/// delegated to <see cref="Osd"/>.
/// </summary>
public partial class PlayerViewModel : ViewModelBase, IDisposable, INavigationAware
{
    private readonly IPlayerService _playerService;
    private readonly ITimeshiftService _timeshiftService;
    private readonly ISleepTimerService _sleepTimerService;

    private IDisposable? _playerSubscription;
    private IDisposable? _timeshiftSubscription;
    private IDisposable? _sleepTimerSubscription;

    private DispatcherTimer? _zapDismissTimer;
    private DispatcherTimer? _autoPlayCountdownTimer;
    private DispatcherTimer? _directTuneTimer;
    private DispatcherTimer? _screensaverTimer;
    private DispatcherTimer? _statsRefreshTimer;

    private PlaybackRequest? _currentRequest;
    private PlaybackRequest? _pipSavedRequest;
    private TimeSpan _pipSavedPosition;

    private JellyfinSegmentMarker[] _introMarkers = [];
    private JellyfinSegmentMarker[] _creditsMarkers = [];

    private string _directTuneAccumulator = string.Empty;

    // ─── OSD sub-ViewModel ───────────────────────────────────────────────────

    /// <summary>OSD display state (channel info, visibility, skip markers, auto-play, etc.).</summary>
    public OsdViewModel Osd { get; } = new();

    // ─── Forwarding properties ────────────────────────────────────────────────
    // These delegate reads/writes to Osd so existing call sites and tests need no change.

    /// <summary>Forwarded to <see cref="OsdViewModel.IsOsdVisible"/>.</summary>
    public bool IsOsdVisible
    {
        get => Osd.IsOsdVisible;
        set => Osd.IsOsdVisible = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.ChannelLogoUrl"/>.</summary>
    public string? ChannelLogoUrl
    {
        get => Osd.ChannelLogoUrl;
        set => Osd.ChannelLogoUrl = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.ChannelName"/>.</summary>
    public string? ChannelName
    {
        get => Osd.ChannelName;
        set => Osd.ChannelName = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.CurrentProgramme"/>.</summary>
    public string? CurrentProgramme
    {
        get => Osd.CurrentProgramme;
        set => Osd.CurrentProgramme = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.TimeshiftOffset"/>.</summary>
    public string TimeshiftOffset
    {
        get => Osd.TimeshiftOffset;
        set => Osd.TimeshiftOffset = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.ShowGoLive"/>.</summary>
    public bool ShowGoLive
    {
        get => Osd.ShowGoLive;
        set => Osd.ShowGoLive = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.ShowSkipIntro"/>.</summary>
    public bool ShowSkipIntro
    {
        get => Osd.ShowSkipIntro;
        set => Osd.ShowSkipIntro = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.ShowSkipCredits"/>.</summary>
    public bool ShowSkipCredits
    {
        get => Osd.ShowSkipCredits;
        set => Osd.ShowSkipCredits = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.ShowAutoPlayCountdown"/>.</summary>
    public bool ShowAutoPlayCountdown
    {
        get => Osd.ShowAutoPlayCountdown;
        set => Osd.ShowAutoPlayCountdown = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.AutoPlayCountdownSeconds"/>.</summary>
    public int AutoPlayCountdownSeconds
    {
        get => Osd.AutoPlayCountdownSeconds;
        set => Osd.AutoPlayCountdownSeconds = value;
    }

    /// <summary>Forwarded to <see cref="OsdViewModel.ShowAreYouStillWatching"/>.</summary>
    public bool ShowAreYouStillWatching
    {
        get => Osd.ShowAreYouStillWatching;
        set => Osd.ShowAreYouStillWatching = value;
    }

    // ─── Playback state mirrors ──────────────────────────────────────────────

    [ObservableProperty]
    private bool _isPlaying;

    [ObservableProperty]
    private bool _isBuffering;

    [ObservableProperty]
    private bool _isLive;

    [ObservableProperty]
    private bool _isAudioOnly;

    [ObservableProperty]
    private PlaybackMode _mode;

    [ObservableProperty]
    private float _volume = 1.0f;

    [ObservableProperty]
    private bool _isMuted;

    [ObservableProperty]
    private TimeSpan _position;

    [ObservableProperty]
    private TimeSpan _duration;

    [ObservableProperty]
    private float _rate = 1.0f;

    [ObservableProperty]
    private string? _errorMessage;

    [ObservableProperty]
    private int _retryCount;

    // ─── Track lists ────────────────────────────────────────────────────────

    [ObservableProperty]
    private IReadOnlyList<TrackInfo> _audioTracks = [];

    [ObservableProperty]
    private IReadOnlyList<TrackInfo> _subtitleTracks = [];

    [ObservableProperty]
    private bool _isTrackSelectorOpen;

    // ─── Quality display ─────────────────────────────────────────────────────

    [ObservableProperty]
    private string? _qualityDisplay;

    // ─── Timeshift (playback-state mirror; OSD display copy lives in Osd) ────

    [ObservableProperty]
    private bool _isTimeshifted;

    // ─── Zap overlay ────────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _showZapOverlay;

    // ─── Direct-tune overlay ────────────────────────────────────────────────

    [ObservableProperty]
    private bool _directTuneActive;

    [ObservableProperty]
    private string _directTuneDisplay = string.Empty;

    // ─── Auto-play supporting state ──────────────────────────────────────────

    [ObservableProperty]
    private bool _showPostPlay;

    [ObservableProperty]
    private int _episodesWatchedCount;

    // ─── Chapters (Jellyfin VOD) ─────────────────────────────────────────────

    [ObservableProperty]
    private ObservableCollection<ChapterMark> _chapters = [];

    // ─── EPG programmes in timeshift buffer ──────────────────────────────────

    [ObservableProperty]
    private ObservableCollection<EpgProgrammeRef> _bufferProgrammes = [];

    // ─── Player handoff (PLR-22/23/24) ───────────────────────────────────────

    [ObservableProperty]
    private bool _isHandoffInProgress;

    // ─── Sleep timer ─────────────────────────────────────────────────────────

    [ObservableProperty]
    private TimeSpan? _sleepTimerRemaining;

    // ─── Catchup restart ─────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _canRestartFromCatchup;

    // ─── Stream stats overlay (I key, PLR-33) ────────────────────────────────

    [ObservableProperty]
    private bool _isStreamStatsVisible;

    [ObservableProperty]
    private string _statsCodecVideo = string.Empty;

    [ObservableProperty]
    private string _statsCodecAudio = string.Empty;

    [ObservableProperty]
    private string _statsResolution = string.Empty;

    [ObservableProperty]
    private string _statsBitrateKbps = string.Empty;

    [ObservableProperty]
    private string _statsFps = string.Empty;

    [ObservableProperty]
    private string _statsLatencyMs = string.Empty;

    [ObservableProperty]
    private string _statsPacketLoss = string.Empty;

    // ─── Screensaver (PLR-33) ────────────────────────────────────────────────

    [ObservableProperty]
    private bool _isScreensaverActive;

    /// <summary>Inactivity timeout before screensaver activates. Default 10 minutes.</summary>
    public int ScreensaverTimeoutSeconds { get; set; } = 600;

    // ─── Bookmarks overlay (PLR-33) ──────────────────────────────────────────

    [ObservableProperty]
    private bool _isBookmarksOverlayOpen;

    [ObservableProperty]
    private ObservableCollection<Crispy.Application.Player.Models.Bookmark> _bookmarks = [];

    // ─── Player queue overlay (PLR-33) ───────────────────────────────────────

    [ObservableProperty]
    private bool _isQueueOverlayOpen;

    [ObservableProperty]
    private ObservableCollection<Crispy.Application.Player.Models.QueueItem> _queue = [];

    // ─── Live EPG strip (PLR-33) ─────────────────────────────────────────────

    [ObservableProperty]
    private string? _currentProgrammeTitle;

    [ObservableProperty]
    private string? _nextProgrammeTitle;

    [ObservableProperty]
    private string? _nextProgrammeStartTime;

    [ObservableProperty]
    private double _currentProgrammeProgress;

    // ─── Computed properties ─────────────────────────────────────────────────

    /// <summary>Speed controls are disabled for live TV (PLR-07).</summary>
    public bool IsSpeedEnabled => !IsLive && Mode != PlaybackMode.Radio;

    /// <summary>Exposes the underlying service so code-behind can wire VideoView.MediaPlayer.</summary>
    public IPlayerService PlayerService => _playerService;

    /// <summary>Audio sample stream for WaveformVisualizer.</summary>
    public IObservable<float[]> AudioSamples => _playerService.AudioSamples;

    // ─────────────────────────────────────────────────────────────────────────

    public PlayerViewModel(
        IPlayerService playerService,
        ITimeshiftService timeshiftService,
        ISleepTimerService sleepTimerService)
    {
        Title = "Player";
        _playerService = playerService;
        _timeshiftService = timeshiftService;
        _sleepTimerService = sleepTimerService;

        InitTimers();
        SubscribeToServices();
    }

    // ─── Initialisation ──────────────────────────────────────────────────────

    private void InitTimers()
    {
        // DispatcherTimer requires a running UI thread — unavailable in unit test environments.
        // OsdViewModel owns the OSD hide timer; this method initialises the remaining timers.
        try
        {
            InitScreensaverTimer();
            InitStatsRefreshTimer();
        }
        catch (Exception)
        {
            // No dispatcher available (unit test environment) — timers not started.
        }
    }

    private void InitScreensaverTimer()
    {
        _screensaverTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(ScreensaverTimeoutSeconds) };
        _screensaverTimer.Tick += (_, _) =>
        {
            _screensaverTimer?.Stop();
            IsScreensaverActive = true;
        };
    }

    private void InitStatsRefreshTimer()
    {
        _statsRefreshTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _statsRefreshTimer.Tick += (_, _) => RefreshStreamStats();
    }

    private void RefreshStreamStats()
    {
        var state = _playerService.State;
        if (state.CurrentVideoWidth.HasValue && state.CurrentVideoHeight.HasValue)
            StatsResolution = $"{state.CurrentVideoWidth}×{state.CurrentVideoHeight}";
        else
            StatsResolution = "—";
        // Codec and bitrate require VLC media stats API — populated when available via StateChanged.
    }

    private void SubscribeToServices()
    {
        _playerSubscription = _playerService.StateChanged.Subscribe(OnPlayerStateChanged);
        _timeshiftSubscription = _timeshiftService.StateChanged.Subscribe(OnTimeshiftStateChanged);
        _sleepTimerSubscription = _sleepTimerService.RemainingChanged.Subscribe(r => RunOnUiThread(() => SleepTimerRemaining = r));
        _sleepTimerService.TimerElapsed += async (_, _) => await _playerService.StopAsync();
    }

    // ─── State change handlers ────────────────────────────────────────────────

    /// <summary>
    /// Runs action on UI thread if one is available.
    /// Falls back to inline execution in unit test environments (no running Avalonia app).
    /// </summary>
    private static void RunOnUiThread(Action action)
    {
        try
        {
            if (Dispatcher.UIThread.CheckAccess())
                action();
            else
                Dispatcher.UIThread.Post(action);
        }
        catch (Exception)
        {
            // No UI thread running (unit test environment) — run inline.
            action();
        }
    }

    private void OnPlayerStateChanged(PlayerState state)
    {
        RunOnUiThread(() =>
        {
            IsPlaying = state.IsPlaying;
            IsBuffering = state.IsBuffering;
            IsLive = state.IsLive;
            IsAudioOnly = state.IsAudioOnly;
            Mode = state.Mode;
            Volume = state.Volume;
            IsMuted = state.IsMuted;
            Position = state.Position;
            Duration = state.Duration;
            Rate = state.Rate;
            AudioTracks = state.AudioTracks;
            SubtitleTracks = state.SubtitleTracks;
            ErrorMessage = state.ErrorMessage;
            IsTimeshifted = state.Mode == PlaybackMode.Timeshifted;
            OnPropertyChanged(nameof(IsSpeedEnabled));

            // Sync OSD display copies
            Osd.IsLive = state.IsLive;
            Osd.IsTimeshifted = IsTimeshifted;

            UpdateQualityDisplay(state);
            UpdateChannelInfo(state);
            CheckSkipMarkers(state.Position);
            CheckAutoPlay(state);
            HandleError(state);
        });
    }

    private void OnTimeshiftStateChanged(TimeshiftState ts)
    {
        RunOnUiThread(() =>
        {
            Osd.TimeshiftOffset = ts.OffsetDisplay;
            Osd.ShowGoLive = IsTimeshifted && !ts.IsAtLiveEdge;
        });
    }

    private void UpdateQualityDisplay(PlayerState state)
    {
        if (state.CurrentVideoWidth.HasValue && state.CurrentVideoHeight.HasValue)
            QualityDisplay = $"Auto · {state.CurrentVideoHeight}p";
        else
            QualityDisplay = null;
    }

    private void UpdateChannelInfo(PlayerState state)
    {
        if (state.CurrentRequest is { } req)
        {
            Osd.ChannelLogoUrl = req.ChannelLogoUrl;
            Osd.ChannelName = req.Title;
        }
    }

    private void CheckSkipMarkers(TimeSpan position)
    {
        Osd.ShowSkipIntro = _introMarkers.Any(m => position >= m.Start && position <= m.End);
        Osd.ShowSkipCredits = _creditsMarkers.Any(m => position >= m.Start && position <= m.End);
    }

    private void CheckAutoPlay(PlayerState state)
    {
        if (state.Duration == TimeSpan.Zero || Mode != PlaybackMode.Vod) return;
        var nearEnd = state.Duration - state.Position <= TimeSpan.FromSeconds(30);
        if (nearEnd && !Osd.ShowAutoPlayCountdown && !ShowPostPlay)
            StartAutoPlayCountdown();
    }

    private void HandleError(PlayerState state)
    {
        if (state.ErrorMessage is null) return;
        RetryCount++;
        if (RetryCount <= 3 && _currentRequest is { } req)
        {
            var captured = req;
            _ = Task.Delay(TimeSpan.FromSeconds(2)).ContinueWith(_ =>
                Dispatcher.UIThread.Post(async () =>
                    await _playerService.PlayAsync(captured)));
        }
    }

    // ─── OSD auto-hide ───────────────────────────────────────────────────────

    /// <summary>Called from code-behind on pointer-moved or tap to show and reset OSD timer.</summary>
    public void ShowOsd()
    {
        Osd.ShowOsd();
        DismissScreensaver();
    }

    /// <summary>Resets the screensaver inactivity timer. Call on any user input.</summary>
    public void ResetScreensaverTimer()
    {
        _screensaverTimer?.Stop();
        if (IsPlaying)
        {
            _screensaverTimer?.Start();
        }
    }

    /// <summary>Dismisses the screensaver and resets the inactivity timer.</summary>
    public void DismissScreensaver()
    {
        IsScreensaverActive = false;
        ResetScreensaverTimer();
    }

    /// <summary>Toggles stream stats overlay visibility (I key, PLR-33).</summary>
    public void ToggleStreamStats()
    {
        IsStreamStatsVisible = !IsStreamStatsVisible;
        if (IsStreamStatsVisible)
        {
            _statsRefreshTimer?.Start();
            RefreshStreamStats();
        }
        else
        {
            _statsRefreshTimer?.Stop();
        }
    }

    // ─── Autoplay countdown ──────────────────────────────────────────────────

    private void StartAutoPlayCountdown()
    {
        Osd.AutoPlayCountdownSeconds = 5;
        Osd.ShowAutoPlayCountdown = true;
        _autoPlayCountdownTimer?.Stop();
        _autoPlayCountdownTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _autoPlayCountdownTimer.Tick += (_, _) =>
        {
            Osd.AutoPlayCountdownSeconds--;
            if (Osd.AutoPlayCountdownSeconds <= 0)
            {
                _autoPlayCountdownTimer!.Stop();
                AutoPlayNextCommand.Execute(null);
            }
        };
        _autoPlayCountdownTimer.Start();
    }

    // ─── Direct-tune helper ──────────────────────────────────────────────────

    private void AccumulateDirectTune(string digit)
    {
        _directTuneAccumulator += digit;
        DirectTuneDisplay = _directTuneAccumulator;
        DirectTuneActive = true;

        _directTuneTimer?.Stop();
        _directTuneTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _directTuneTimer.Tick += (_, _) =>
        {
            _directTuneTimer!.Stop();
            DirectTuneActive = false;
            if (int.TryParse(_directTuneAccumulator, out var n))
                DirectTuneCommand.Execute(n);
            _directTuneAccumulator = string.Empty;
            DirectTuneDisplay = string.Empty;
        };
        _directTuneTimer.Start();
    }

    // ─── Segment markers ─────────────────────────────────────────────────────

    /// <summary>Called when Jellyfin provides segment data for the current VOD item.</summary>
    public void SetSegmentMarkers(JellyfinSegmentMarker[] intro, JellyfinSegmentMarker[] credits)
    {
        _introMarkers = intro;
        _creditsMarkers = credits;
    }

    // ─── Commands ────────────────────────────────────────────────────────────

    [RelayCommand]
    private async Task PlayAsync(PlaybackRequest request)
    {
        _currentRequest = request;
        RetryCount = 0;
        Osd.ChannelName = request.Title;
        Osd.ChannelLogoUrl = request.ChannelLogoUrl;
        await _playerService.PlayAsync(request);
    }

    [RelayCommand]
    private Task PauseAsync() => _playerService.PauseAsync();

    [RelayCommand]
    private Task ResumeAsync() => _playerService.ResumeAsync();

    [RelayCommand]
    private Task StopAsync() => _playerService.StopAsync();

    [RelayCommand]
    private Task SeekAsync(TimeSpan position) => _playerService.SeekAsync(position);

    [RelayCommand]
    private Task SetRateAsync(float rate) => IsLive ? Task.CompletedTask : _playerService.SetRateAsync(rate);

    [RelayCommand]
    private async Task GoLiveAsync()
    {
        await _timeshiftService.GoLiveAsync();
        if (_currentRequest is not null)
            await _playerService.PlayAsync(_currentRequest with { EnableTimeshift = true });
    }

    [RelayCommand]
    private async Task SkipIntroAsync()
    {
        if (_introMarkers.Length > 0)
            await _playerService.SeekAsync(_introMarkers[0].End);
        Osd.ShowSkipIntro = false;
    }

    [RelayCommand]
    private async Task SkipCreditsAsync()
    {
        if (_creditsMarkers.Length > 0)
            await _playerService.SeekAsync(_creditsMarkers[0].End);
        Osd.ShowSkipCredits = false;
    }

    [RelayCommand]
    private void OpenTrackSelector() => IsTrackSelectorOpen = true;

    [RelayCommand]
    private void CloseTrackSelector() => IsTrackSelectorOpen = false;

    [RelayCommand]
    private Task ToggleFullscreenAsync() => Task.CompletedTask; // wired in code-behind

    [RelayCommand]
    private void TogglePip()
    {
        if (_currentRequest is not null)
        {
            _pipSavedRequest = _currentRequest;
            _pipSavedPosition = Position;
        }
        // Platform bridge fires RestoreFromPipAsync on return
    }

    /// <summary>Called by the platform bridge when the app returns from PiP (PLR-28).</summary>
    public async Task RestoreFromPipAsync()
    {
        if (_pipSavedRequest is null) return;
        await _playerService.PlayAsync(_pipSavedRequest with { ResumeAt = _pipSavedPosition });
        _pipSavedRequest = null;
        _pipSavedPosition = TimeSpan.Zero;
    }

    [RelayCommand]
    private Task ToggleMuteAsync() => _playerService.MuteAsync(!IsMuted);

    [RelayCommand]
    private Task SetVolumeAsync(float volume) => _playerService.SetVolumeAsync(volume);

    [RelayCommand]
    private Task SetAspectRatioAsync(string? ratio) => _playerService.SetAspectRatioAsync(ratio);

    [RelayCommand]
    private async Task RetryAsync()
    {
        ErrorMessage = null;
        RetryCount = 0;
        if (_currentRequest is not null)
            await _playerService.PlayAsync(_currentRequest);
    }

    [RelayCommand]
    private void PreviousChannel() => TriggerZapOverlay();

    [RelayCommand]
    private void NextChannel() => TriggerZapOverlay();

    private void TriggerZapOverlay()
    {
        ShowZapOverlay = true;
        _zapDismissTimer?.Stop();
        _zapDismissTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(4) };
        _zapDismissTimer.Tick += (_, _) =>
        {
            _zapDismissTimer!.Stop();
            ShowZapOverlay = false;
        };
        _zapDismissTimer.Start();
    }

    [RelayCommand]
    private void DirectTune(int channelNumber)
    {
        DirectTuneActive = false;
        DirectTuneDisplay = string.Empty;
        // Navigation to channel number handled externally
    }

    /// <summary>Called from code-behind keyboard handler for digit keys 0-9.</summary>
    public void HandleDigitKey(string digit) => AccumulateDirectTune(digit);

    [RelayCommand]
    private void OpenSleepTimer() { /* opens sleep timer panel */ }

    [RelayCommand]
    private void SetSleepTimer(TimeSpan duration) => _sleepTimerService.SetTimer(duration);

    [RelayCommand]
    private void AutoPlayNext()
    {
        Osd.ShowAutoPlayCountdown = false;
        _autoPlayCountdownTimer?.Stop();
        EpisodesWatchedCount++;
        if (EpisodesWatchedCount >= 3)
            Osd.ShowAreYouStillWatching = true;
        // Navigation to next episode handled externally
    }

    [RelayCommand]
    private void CancelAutoPlay()
    {
        Osd.ShowAutoPlayCountdown = false;
        _autoPlayCountdownTimer?.Stop();
    }

    [RelayCommand]
    private void ContinueWatching()
    {
        Osd.ShowAreYouStillWatching = false;
        EpisodesWatchedCount = 0;
    }

    [RelayCommand]
    private async Task StopWatchingAsync()
    {
        Osd.ShowAreYouStillWatching = false;
        await _playerService.StopAsync();
    }

    [RelayCommand]
    private async Task OpenExternalPlayerAsync()
    {
        if (_currentRequest is null) return;
        var url = _currentRequest.Url;
        var userAgent = _currentRequest.UserAgent ?? string.Empty;

#if ANDROID
        // Android: fire event — platform bridge launches Intent.ActionView
        ExternalPlayerRequested?.Invoke(this, url);
        await Task.CompletedTask;
#elif IOS
        // iOS: VLC URL scheme
        ExternalPlayerRequested?.Invoke(this, $"vlc://{url}");
        await Task.CompletedTask;
#else
        await LaunchDesktopExternalPlayerAsync(url, userAgent);
#endif
    }

    private static Task LaunchDesktopExternalPlayerAsync(string url, string userAgent)
    {
        string? playerExe = FindPlayerOnPath("vlc", "mpv", "mpvnet", "potplayer", "mpc-hc64");
        if (playerExe is null)
        {
            Process.Start(new ProcessStartInfo { FileName = url, UseShellExecute = true });
            return Task.CompletedTask;
        }

        var args = $"\"{url}\"";
        if (!string.IsNullOrEmpty(userAgent))
        {
            if (playerExe.Contains("vlc", StringComparison.OrdinalIgnoreCase))
                args += $" --http-user-agent=\"{userAgent}\"";
            else if (playerExe.Contains("mpv", StringComparison.OrdinalIgnoreCase))
                args += $" --user-agent=\"{userAgent}\"";
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = playerExe,
            Arguments = args,
            UseShellExecute = true,
        });
        return Task.CompletedTask;
    }

    private static string? FindPlayerOnPath(params string[] candidates)
    {
        var pathEnv = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        var dirs = pathEnv.Split(Path.PathSeparator);
        string[] exts = OperatingSystem.IsWindows() ? [".exe"] : [string.Empty];
        foreach (var candidate in candidates)
            foreach (var dir in dirs)
                foreach (var ext in exts)
                {
                    var full = Path.Combine(dir, candidate + ext);
                    if (File.Exists(full)) return full;
                }
        return null;
    }

    /// <summary>Raised when external player launch is requested (Android / iOS).</summary>
#pragma warning disable CS0067 // event used inside #if ANDROID / #if IOS blocks
    public event EventHandler<string>? ExternalPlayerRequested;
#pragma warning restore CS0067

    [RelayCommand]
    private async Task CycleSubtitleTrackAsync()
    {
        var tracks = SubtitleTracks;
        if (tracks.Count == 0) return;
        var current = tracks.FirstOrDefault(t => t.IsSelected);
        var currentIdx = current is null ? -1 : FindIndex(tracks, t => t.Id == current.Id);
        var idx = currentIdx < 0 ? 0 : (currentIdx + 1) % tracks.Count;
        await _playerService.SetSubtitleTrackAsync(tracks[idx].Id);
    }

    [RelayCommand]
    private void NextEpisode() => EpisodesWatchedCount++;

    [RelayCommand]
    private void AddBookmark() => BookmarkRequested?.Invoke(this, Position);

    /// <summary>Raised when a bookmark should be created at the current position (B key, PLR-21).</summary>
    public event EventHandler<TimeSpan>? BookmarkRequested;

    [RelayCommand]
    private void OpenEqualizer() => EqualizerRequested?.Invoke(this, EventArgs.Empty);

    /// <summary>Raised when the equalizer overlay should open (E key, PLR-21).</summary>
    public event EventHandler? EqualizerRequested;

    [RelayCommand]
    private async Task IncreaseSpeedAsync()
    {
        if (IsLive) return;
        await _playerService.SetRateAsync(SpeedPresets.Next(Rate));
    }

    [RelayCommand]
    private async Task DecreaseSpeedAsync()
    {
        if (IsLive) return;
        await _playerService.SetRateAsync(SpeedPresets.Previous(Rate));
    }

    [RelayCommand]
    private async Task HandoffToNativePlayerAsync()
    {
        IsHandoffInProgress = true;
        await Task.Delay(50); // yield for UI to block input
        // Platform bridge sets IsHandoffInProgress = false via CompleteHandoff()
    }

    /// <summary>Called by platform bridge when native player handoff completes (PLR-22/23/24).</summary>
    public void CompleteHandoff() => IsHandoffInProgress = false;

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static int FindIndex<T>(IReadOnlyList<T> list, Func<T, bool> predicate)
    {
        for (var i = 0; i < list.Count; i++)
            if (predicate(list[i])) return i;
        return -1;
    }

    // ─── Navigation lifecycle ─────────────────────────────────────────────────

    /// <inheritdoc />
    public void OnNavigatedTo(object? parameter)
    {
        if (parameter is PlaybackRequest request)
            PlayCommand.Execute(request);
    }

    /// <inheritdoc />
    public void OnNavigatedFrom() { }

    // ─── Cleanup ─────────────────────────────────────────────────────────────

    public void Dispose()
    {
        _playerSubscription?.Dispose();
        _timeshiftSubscription?.Dispose();
        _sleepTimerSubscription?.Dispose();
        Osd.StopTimer();
        _zapDismissTimer?.Stop();
        _autoPlayCountdownTimer?.Stop();
        _directTuneTimer?.Stop();
        _screensaverTimer?.Stop();
        _statsRefreshTimer?.Stop();
    }
}

// ─── ViewModel-layer supporting types ────────────────────────────────────────

/// <summary>Jellyfin intro / credits segment marker.</summary>
public sealed record JellyfinSegmentMarker(TimeSpan Start, TimeSpan End);

/// <summary>EPG programme reference used by LiveSeekBar for buffer-range tick marks.</summary>
public sealed record EpgProgrammeRef(string Title, DateTimeOffset StartTime, DateTimeOffset EndTime);

/// <summary>Chapter marker for VodSeekBar tick marks.</summary>
public sealed record ChapterMark(TimeSpan Position, string Title);

/// <summary>Playback speed preset helpers.</summary>
internal static class SpeedPresets
{
    private static readonly float[] Presets = [0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f];

    public static float Next(float current)
    {
        var idx = Array.IndexOf(Presets, current);
        return idx >= 0 && idx < Presets.Length - 1 ? Presets[idx + 1] : current;
    }

    public static float Previous(float current)
    {
        var idx = Array.IndexOf(Presets, current);
        return idx > 0 ? Presets[idx - 1] : current;
    }
}
