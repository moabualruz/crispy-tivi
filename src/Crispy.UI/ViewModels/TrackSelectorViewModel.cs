using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

namespace Crispy.UI.ViewModels;

/// <summary>Speed option item for the track selector panel.</summary>
public sealed record SpeedOption(float Value, string Label)
{
    public static readonly IReadOnlyList<SpeedOption> All =
    [
        new(0.5f,  "0.5×"),
        new(0.75f, "0.75×"),
        new(1.0f,  "1×"),
        new(1.25f, "1.25×"),
        new(1.5f,  "1.5×"),
        new(2.0f,  "2×"),
    ];
}

/// <summary>
/// ViewModel for the audio/subtitle/speed track selector bottom sheet.
/// Syncs track lists from PlayerViewModel and persists speed preference per ContentType.
/// </summary>
public partial class TrackSelectorViewModel : ViewModelBase
{
    private readonly IPlayerService _playerService;

    [ObservableProperty]
    private ObservableCollection<TrackInfo> _audioTracks = [];

    [ObservableProperty]
    private ObservableCollection<TrackInfo> _subtitleTracks = [];

    /// <summary>Speed options — all presets. Speed section hidden in View when IsLive.</summary>
    public IReadOnlyList<SpeedOption> SpeedOptions { get; } = SpeedOption.All;

    [ObservableProperty]
    private TrackInfo? _selectedAudioTrack;

    [ObservableProperty]
    private TrackInfo? _selectedSubtitleTrack;

    [ObservableProperty]
    private SpeedOption? _selectedSpeed;

    [ObservableProperty]
    private bool _isLive;

    public TrackSelectorViewModel(IPlayerService playerService)
    {
        Title = "Track Selector";
        _playerService = playerService;
        _selectedSpeed = SpeedOption.All.FirstOrDefault(s => s.Value == 1.0f);
    }

    /// <summary>Sync track lists from the current PlayerState.</summary>
    public void UpdateFromState(PlayerState state)
    {
        IsLive = state.IsLive;

        AudioTracks.Clear();
        foreach (var t in state.AudioTracks) AudioTracks.Add(t);
        SelectedAudioTrack = state.AudioTracks.FirstOrDefault(t => t.IsSelected);

        SubtitleTracks.Clear();
        foreach (var t in state.SubtitleTracks) SubtitleTracks.Add(t);
        SelectedSubtitleTrack = state.SubtitleTracks.FirstOrDefault(t => t.IsSelected);

        if (!IsLive)
        {
            var match = SpeedOption.All.FirstOrDefault(s => MathF.Abs(s.Value - state.Rate) < 0.01f);
            SelectedSpeed = match ?? SpeedOption.All.FirstOrDefault(s => s.Value == 1.0f);
        }
    }

    [RelayCommand]
    private async Task SelectAudioTrackAsync(TrackInfo track)
    {
        SelectedAudioTrack = track;
        await _playerService.SetAudioTrackAsync(track.Id);
    }

    [RelayCommand]
    private async Task SelectSubtitleTrackAsync(TrackInfo track)
    {
        SelectedSubtitleTrack = track;
        await _playerService.SetSubtitleTrackAsync(track.Id);
    }

    [RelayCommand]
    private async Task SetSpeedAsync(SpeedOption option)
    {
        if (IsLive) return;
        SelectedSpeed = option;
        await _playerService.SetRateAsync(option.Value);
    }
}
