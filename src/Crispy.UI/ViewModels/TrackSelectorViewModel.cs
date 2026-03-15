using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

namespace Crispy.UI.ViewModels;

/// <summary>
/// Popover ViewModel for selecting audio/subtitle tracks and playback speed.
/// Stub — full implementation in Wave 2 (03-02).
/// </summary>
public partial class TrackSelectorViewModel : ViewModelBase
{
    private readonly IPlayerService _playerService;

    [ObservableProperty]
    private ObservableCollection<TrackInfo> _audioTracks = [];

    [ObservableProperty]
    private ObservableCollection<TrackInfo> _subtitleTracks = [];

    [ObservableProperty]
    private ObservableCollection<float> _speedOptions = [];

    [ObservableProperty]
    private TrackInfo? _selectedAudioTrack;

    [ObservableProperty]
    private float _selectedSpeed = 1.0f;

    public TrackSelectorViewModel(IPlayerService playerService)
    {
        Title = "Track Selector";
        _playerService = playerService;
    }

    [RelayCommand]
    private Task SelectAudioTrackAsync(TrackInfo track) => Task.CompletedTask;

    [RelayCommand]
    private Task SelectSubtitleTrackAsync(TrackInfo track) => Task.CompletedTask;

    [RelayCommand]
    private Task SetSpeedAsync(float speed) => Task.CompletedTask;
}
