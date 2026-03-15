using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the full-screen player OSD.
/// Stub — full implementation in Wave 2 (03-02).
/// </summary>
public partial class PlayerViewModel : ViewModelBase
{
    private readonly IPlayerService _playerService;

    [ObservableProperty]
    private PlayerState _playerState = PlayerState.Empty;

    [ObservableProperty]
    private bool _isSkipIntroVisible;

    [ObservableProperty]
    private bool _isAutoPlayCountdownVisible;

    [ObservableProperty]
    private int _autoPlayCountdownSeconds;

    [ObservableProperty]
    private bool _isAreYouStillWatchingVisible;

    [ObservableProperty]
    private string _qualityDisplay = string.Empty;

    [ObservableProperty]
    private bool _isSpeedEnabled;

    public PlayerViewModel(IPlayerService playerService)
    {
        Title = "Player";
        _playerService = playerService;
    }

    [RelayCommand]
    private Task SkipIntroAsync() => Task.CompletedTask;

    [RelayCommand]
    private Task ContinueWatchingAsync() => Task.CompletedTask;

    [RelayCommand]
    private Task StillWatchingAsync() => Task.CompletedTask;
}
