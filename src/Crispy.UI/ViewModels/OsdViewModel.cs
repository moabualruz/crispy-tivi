using Avalonia.Threading;

using CommunityToolkit.Mvvm.ComponentModel;

namespace Crispy.UI.ViewModels;

/// <summary>
/// Manages OSD (On-Screen Display) visibility state, channel info, timeshift display,
/// skip markers, auto-play countdown, and still-watching prompt.
/// Created and owned by PlayerViewModel.
/// </summary>
public partial class OsdViewModel : ObservableObject
{
    private DispatcherTimer? _osdHideTimer;

    // ─── OSD visibility ──────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _isOsdVisible = true;

    // ─── Channel info ─────────────────────────────────────────────────────────

    [ObservableProperty]
    private string? _channelLogoUrl;

    [ObservableProperty]
    private string? _channelName;

    [ObservableProperty]
    private string? _currentProgramme;

    // ─── Live / timeshift ─────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _isLive;

    [ObservableProperty]
    private bool _isTimeshifted;

    [ObservableProperty]
    private string _timeshiftOffset = string.Empty;

    [ObservableProperty]
    private bool _showGoLive;

    // ─── Skip markers ─────────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _showSkipIntro;

    [ObservableProperty]
    private bool _showSkipCredits;

    // ─── Auto-play countdown ──────────────────────────────────────────────────

    [ObservableProperty]
    private bool _showAutoPlayCountdown;

    [ObservableProperty]
    private int _autoPlayCountdownSeconds = 5;

    // ─── Still-watching prompt ────────────────────────────────────────────────

    [ObservableProperty]
    private bool _showAreYouStillWatching;

    // ─────────────────────────────────────────────────────────────────────────

    public OsdViewModel()
    {
        InitOsdTimer();
    }

    // ─── OSD auto-hide ────────────────────────────────────────────────────────

    private void InitOsdTimer()
    {
        // DispatcherTimer requires a running UI thread — unavailable in unit test environments.
        try
        {
            _osdHideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
            _osdHideTimer.Tick += (_, _) =>
            {
                IsOsdVisible = false;
                _osdHideTimer?.Stop();
            };
        }
        catch (Exception)
        {
            // No dispatcher available (unit test environment) — timer not started.
        }
    }

    /// <summary>Shows the OSD and resets the auto-hide timer.</summary>
    public void ShowOsd()
    {
        IsOsdVisible = true;
        _osdHideTimer?.Stop();
        _osdHideTimer?.Start();
    }

    /// <summary>Stops the OSD hide timer and disposes it.</summary>
    public void StopTimer()
    {
        _osdHideTimer?.Stop();
    }
}
