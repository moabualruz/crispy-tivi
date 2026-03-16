using System.Threading;
using System.Threading.Tasks;

using Avalonia.Media;
using Avalonia.Threading;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the AppShell root view.
/// Manages the 3-layer visibility state (video, content, player overlay)
/// and delegates navigation to MainViewModel and playback to PlayerViewModel.
/// </summary>
public partial class AppShellViewModel : ViewModelBase
{
    // ─── Injected singletons ──────────────────────────────────────────────────

    /// <summary>Player singleton — always alive, never recreated.</summary>
    public PlayerViewModel Player { get; }

    /// <summary>Navigation manager — owns nav rail and current page.</summary>
    public MainViewModel Navigation { get; }

    // ─── Layer visibility ─────────────────────────────────────────────────────

    /// <summary>Whether the video surface (Layer 0) is visible.</summary>
    [ObservableProperty]
    private bool _isVideoVisible;

    /// <summary>Whether the content/browsing layer (Layer 1) is visible. Defaults true.</summary>
    [ObservableProperty]
    private bool _isContentVisible = true;

    /// <summary>Whether the player overlay (Layer 2 — OSD) is visible.</summary>
    [ObservableProperty]
    private bool _isPlayerOverlayVisible;

    /// <summary>Whether the mini-player bar is visible (playing while browsing).</summary>
    [ObservableProperty]
    private bool _isMiniPlayerVisible;

    /// <summary>Whether the shell is currently in fullscreen mode.</summary>
    [ObservableProperty]
    private bool _isFullscreen;

    // ─── Fullscreen state snapshot ────────────────────────────────────────────

    private bool _preFullscreenContentVisible = true;
    private bool _preFullscreenPlayerOverlayVisible;
    private bool _preFullscreenMiniPlayerVisible;

    // ─── Transition opacity ───────────────────────────────────────────────────

    /// <summary>Opacity of the content/browsing layer — animated during transitions.</summary>
    [ObservableProperty]
    private double _contentOpacity = 1.0;

    /// <summary>Opacity of the player overlay layer — animated during transitions.</summary>
    [ObservableProperty]
    private double _playerOverlayOpacity = 0.0;

    /// <summary>Tracks the active transition so concurrent calls cancel the previous one.</summary>
    private CancellationTokenSource? _transitionCts;

    // ─── Derived visuals ──────────────────────────────────────────────────────

    /// <summary>
    /// Content layer background.
    /// Opaque when not playing; semi-transparent when video plays behind content.
    /// </summary>
    public IBrush ContentBackground =>
        IsVideoVisible && IsContentVisible
            ? new SolidColorBrush(Color.FromArgb(0xCC, 0x00, 0x00, 0x00))
            : new SolidColorBrush(Colors.Transparent);

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// <summary>Creates a new AppShellViewModel with injected dependencies.</summary>
    public AppShellViewModel(PlayerViewModel player, MainViewModel navigation)
    {
        Player = player;
        Navigation = navigation;

        // Subscribe to player IsPlaying changes to keep mini-player bar in sync
        Player.PropertyChanged += OnPlayerPropertyChanged;
    }

    // ─── State transitions ────────────────────────────────────────────────────

    /// <summary>
    /// Transitions to full-screen watching mode.
    /// Boolean flags flip immediately; opacity cross-fade (ContentLayer 300ms out,
    /// PlayerOverlay 200ms in) runs concurrently for a smooth visual transition.
    /// </summary>
    [RelayCommand]
    public void EnterWatchingMode()
    {
        IsVideoVisible = true;
        IsContentVisible = false;
        IsPlayerOverlayVisible = true;
        IsMiniPlayerVisible = false;
        OnPropertyChanged(nameof(ContentBackground));
        _ = AnimateToWatchingAsync();
    }

    /// <summary>
    /// Transitions to browsing mode.
    /// Boolean flags flip immediately; opacity cross-fade (PlayerOverlay 200ms out,
    /// ContentLayer 300ms in) runs concurrently for a smooth visual transition.
    /// </summary>
    [RelayCommand]
    public void EnterBrowsingMode()
    {
        IsContentVisible = true;
        IsPlayerOverlayVisible = false;
        IsMiniPlayerVisible = IsVideoVisible;
        OnPropertyChanged(nameof(ContentBackground));
        _ = AnimateToBrowsingAsync();
    }

    /// <summary>Toggles PiP (mini-player) mode.</summary>
    [RelayCommand]
    public void ToggleMiniPlayer()
    {
        if (!IsVideoVisible) return;

        if (IsContentVisible)
        {
            // Currently browsing with mini-player — go to full watching mode
            EnterWatchingMode();
        }
        else
        {
            // Currently watching — go to browsing with mini-player
            EnterBrowsingMode();
        }
    }

    /// <summary>Toggles fullscreen mode. Saves/restores layer visibility.</summary>
    [RelayCommand]
    public void ToggleFullscreen()
    {
        if (!IsFullscreen)
            EnterFullscreen();
        else
            ExitFullscreen();
    }

    /// <summary>Enters fullscreen: hides content layer, shows player overlay, signals view.</summary>
    public void EnterFullscreen()
    {
        // Save current state so we can restore on exit
        _preFullscreenContentVisible = IsContentVisible;
        _preFullscreenPlayerOverlayVisible = IsPlayerOverlayVisible;
        _preFullscreenMiniPlayerVisible = IsMiniPlayerVisible;

        IsContentVisible = false;
        IsPlayerOverlayVisible = true;
        IsMiniPlayerVisible = false;
        IsFullscreen = true;
        OnPropertyChanged(nameof(ContentBackground));
    }

    /// <summary>Exits fullscreen: restores prior layer visibility, signals view.</summary>
    public void ExitFullscreen()
    {
        IsContentVisible = _preFullscreenContentVisible;
        IsPlayerOverlayVisible = _preFullscreenPlayerOverlayVisible;
        IsMiniPlayerVisible = _preFullscreenMiniPlayerVisible;
        IsFullscreen = false;
        OnPropertyChanged(nameof(ContentBackground));
    }

    // ─── Animated transition helpers ──────────────────────────────────────────

    private async Task AnimateToWatchingAsync()
    {
        var cts = BeginTransition();

        try
        {
            // ContentLayer already hidden (IsContentVisible=false set synchronously).
            // Animate ContentOpacity 1→0 then PlayerOverlayOpacity 0→1 for visual polish
            // on systems where the layer is still composited during the frame.
            ContentOpacity = 1.0;
            await FadeAsync(v => ContentOpacity = v, from: 1.0, to: 0.0, durationMs: 300, cts.Token);

            if (cts.Token.IsCancellationRequested) return;

            PlayerOverlayOpacity = 0.0;
            await FadeAsync(v => PlayerOverlayOpacity = v, from: 0.0, to: 1.0, durationMs: 200, cts.Token);
        }
        catch (TaskCanceledException) { }
    }

    private async Task AnimateToBrowsingAsync()
    {
        var cts = BeginTransition();

        try
        {
            // PlayerOverlay already hidden; ContentLayer already visible (set synchronously).
            // Animate PlayerOverlayOpacity 1→0 then ContentOpacity 0→1 for visual polish.
            PlayerOverlayOpacity = 1.0;
            await FadeAsync(v => PlayerOverlayOpacity = v, from: 1.0, to: 0.0, durationMs: 200, cts.Token);

            if (cts.Token.IsCancellationRequested) return;

            ContentOpacity = 0.0;
            await FadeAsync(v => ContentOpacity = v, from: 0.0, to: 1.0, durationMs: 300, cts.Token);
        }
        catch (TaskCanceledException) { }
    }

    /// <summary>
    /// Steps opacity from <paramref name="from"/> to <paramref name="to"/> over
    /// <paramref name="durationMs"/> milliseconds using 16ms ticks (~60 fps).
    /// Runs on the UI thread via Dispatcher.
    /// </summary>
    private static async Task FadeAsync(
        Action<double> setter,
        double from,
        double to,
        int durationMs,
        CancellationToken ct)
    {
        const int tickMs = 16;
        int steps = Math.Max(1, durationMs / tickMs);
        double delta = (to - from) / steps;

        for (int i = 0; i < steps; i++)
        {
            ct.ThrowIfCancellationRequested();
            double value = from + delta * (i + 1);
            await Dispatcher.UIThread.InvokeAsync(() => setter(value));
            await Task.Delay(tickMs, ct);
        }

        // Ensure exact final value
        await Dispatcher.UIThread.InvokeAsync(() => setter(to));
    }

    /// <summary>Cancels any in-progress transition and returns a new token.</summary>
    private CancellationTokenSource BeginTransition()
    {
        _transitionCts?.Cancel();
        _transitionCts?.Dispose();
        _transitionCts = new CancellationTokenSource();
        return _transitionCts;
    }

    // ─── Player state sync ────────────────────────────────────────────────────

    private void OnPlayerPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(PlayerViewModel.IsPlaying))
        {
            if (Player.IsPlaying && !IsVideoVisible)
            {
                // Playback just started — enter watching mode
                EnterWatchingMode();
            }
            else if (!Player.IsPlaying && IsVideoVisible)
            {
                // Playback stopped — return to browsing, hide video
                IsVideoVisible = false;
                IsPlayerOverlayVisible = false;
                IsMiniPlayerVisible = false;
                IsContentVisible = true;
                ContentOpacity = 1.0;
                PlayerOverlayOpacity = 0.0;
                OnPropertyChanged(nameof(ContentBackground));
            }
        }
    }
}
