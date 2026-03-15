using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the picture-in-picture mini-player shown while browsing other screens.
/// Shares IPlayerService state with PlayerViewModel.
/// </summary>
public partial class MiniPlayerViewModel : ViewModelBase
{
    private readonly IPlayerService _playerService;
    private IDisposable? _subscription;

    [ObservableProperty]
    private bool _isVisible;

    [ObservableProperty]
    private string? _channelLogoUrl;

    [ObservableProperty]
    private string? _channelName;

    [ObservableProperty]
    private bool _isPlaying;

    public MiniPlayerViewModel(IPlayerService playerService)
    {
        Title = "Mini Player";
        _playerService = playerService;
        _subscription = _playerService.StateChanged.Subscribe(state =>
        {
            IsVisible = state.IsPlaying || state.IsBuffering;
            IsPlaying = state.IsPlaying;
            if (state.CurrentRequest is { } req)
            {
                ChannelLogoUrl = req.ChannelLogoUrl;
                ChannelName = req.Title;
            }
        });
    }

    [RelayCommand]
    private void Expand()
    {
        // Navigation to full PlayerView handled by host screen
        ExpandRequested?.Invoke(this, EventArgs.Empty);
    }

    /// <summary>Raised when user taps the mini-player to expand to full screen.</summary>
    public event EventHandler? ExpandRequested;

    [RelayCommand]
    private Task PauseAsync() => _playerService.PauseAsync();

    [RelayCommand]
    private Task ResumeAsync() => _playerService.ResumeAsync();

    [RelayCommand]
    private Task StopAsync()
    {
        IsVisible = false;
        return _playerService.StopAsync();
    }

    public void Dispose() => _subscription?.Dispose();
}
