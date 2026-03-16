using Avalonia.Media;

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

    /// <summary>Transitions to full-screen watching mode: hides content, shows OSD.</summary>
    [RelayCommand]
    public void EnterWatchingMode()
    {
        IsVideoVisible = true;
        IsContentVisible = false;
        IsPlayerOverlayVisible = true;
        IsMiniPlayerVisible = false;
        OnPropertyChanged(nameof(ContentBackground));
    }

    /// <summary>Transitions to browsing mode: shows content, hides OSD, shows mini-player.</summary>
    [RelayCommand]
    public void EnterBrowsingMode()
    {
        IsContentVisible = true;
        IsPlayerOverlayVisible = false;
        IsMiniPlayerVisible = IsVideoVisible; // show mini-player only if something is playing
        OnPropertyChanged(nameof(ContentBackground));
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
                OnPropertyChanged(nameof(ContentBackground));
            }
        }
    }
}
