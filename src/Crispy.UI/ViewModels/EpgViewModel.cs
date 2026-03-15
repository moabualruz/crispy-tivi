using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

namespace Crispy.UI.ViewModels;

/// <summary>
/// Display wrapper for an EPG programme entry, adding formatted time and current-highlight flag.
/// </summary>
public sealed class EpgProgrammeItem
{
    /// <summary>The underlying EPG programme.</summary>
    public EpgProgramme Programme { get; }

    /// <summary>Whether this programme is currently airing.</summary>
    public bool IsCurrent { get; }

    /// <summary>Formatted local time range string, e.g. "20:00 – 21:30".</summary>
    public string TimeRange { get; }

    /// <summary>
    /// Creates a new EpgProgrammeItem.
    /// </summary>
    public EpgProgrammeItem(EpgProgramme programme, bool isCurrent)
    {
        Programme = programme;
        IsCurrent = isCurrent;
        var start = programme.StartUtc.ToLocalTime();
        var stop = programme.StopUtc.ToLocalTime();
        TimeRange = $"{start:HH:mm} – {stop:HH:mm}";
    }
}

/// <summary>
/// ViewModel for the EPG (Electronic Programme Guide) screen.
/// Presents a channel list on the left and programme timeline on the right.
/// </summary>
public partial class EpgViewModel : ViewModelBase
{
    private readonly IEpgRepository _epgRepository;
    private readonly IChannelRepository _channelRepository;
    private readonly ISourceRepository _sourceRepository;

    [ObservableProperty]
    private ObservableCollection<Channel> _channels = [];

    [ObservableProperty]
    private Channel? _selectedChannel;

    [ObservableProperty]
    private ObservableCollection<EpgProgrammeItem> _programmeItems = [];

    [ObservableProperty]
    private EpgProgramme? _currentProgramme;

    [ObservableProperty]
    private bool _isLoading;

    /// <summary>
    /// Creates a new EpgViewModel and begins loading channels.
    /// </summary>
    public EpgViewModel(
        IEpgRepository epgRepository,
        IChannelRepository channelRepository,
        ISourceRepository sourceRepository)
    {
        Title = "TV Guide";
        _epgRepository = epgRepository;
        _channelRepository = channelRepository;
        _sourceRepository = sourceRepository;

        _ = LoadChannelsAsync();
    }

    /// <summary>
    /// Loads all channels from all enabled sources.
    /// </summary>
    [RelayCommand]
    public async Task LoadChannelsAsync(CancellationToken ct = default)
    {
        IsLoading = true;
        try
        {
            var sources = await _sourceRepository.GetAllAsync();
            var allChannels = new List<Channel>();

            foreach (var source in sources)
            {
                var batch = await _channelRepository.GetBySourceAsync(source.Id, ct);
                allChannels.AddRange(batch);
            }

            Channels = new ObservableCollection<Channel>(allChannels);
        }
        finally
        {
            IsLoading = false;
        }
    }

    partial void OnSelectedChannelChanged(Channel? value)
    {
        if (value is not null)
        {
            _ = LoadProgrammesAsync(value);
        }
        else
        {
            ProgrammeItems = [];
            CurrentProgramme = null;
        }
    }

    private async Task LoadProgrammesAsync(Channel channel, CancellationToken ct = default)
    {
        IsLoading = true;
        try
        {
            var channelId = string.IsNullOrEmpty(channel.TvgId) ? channel.Title : channel.TvgId;
            var from = DateTime.UtcNow.AddDays(-7);
            var to = DateTime.UtcNow.AddDays(3);

            var results = await _epgRepository.GetProgrammesAsync(channelId, from, to, ct);

            var now = DateTime.UtcNow;
            CurrentProgramme = results.FirstOrDefault(p => p.StartUtc <= now && now < p.StopUtc);

            ProgrammeItems = new ObservableCollection<EpgProgrammeItem>(
                results.Select(p => new EpgProgrammeItem(p, p == CurrentProgramme)));
        }
        finally
        {
            IsLoading = false;
        }
    }
}
