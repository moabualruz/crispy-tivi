using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Crispy.Application.Player.Models;
using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;

namespace Crispy.UI.ViewModels;


/// <summary>
/// A chip item for the source selector bar.
/// null SourceId means "All Sources".
/// </summary>
public sealed record SourceFilterItem(int? SourceId, string Name);

/// <summary>
/// ViewModel for the Live TV screen.
/// Loads channels from IChannelRepository grouped / filtered by source.
/// Implements INavigationAware to reload data when navigated back to after a sync.
/// </summary>
public partial class LiveTvViewModel : ViewModelBase, INavigationAware
{
    private readonly IChannelRepository _channelRepository;
    private readonly ISourceRepository _sourceRepository;
    private readonly INavigationService _navigationService;
    private readonly IPlayerController _playerController;

    [ObservableProperty]
    private ObservableCollection<Channel> _channels = [];

    [ObservableProperty]
    private ObservableCollection<SourceFilterItem> _sourceFilters = [];

    [ObservableProperty]
    private SourceFilterItem? _selectedSourceFilter;

    /// <summary>
    /// Distinct group names extracted from loaded channels.
    /// First entry is always "All" (null group means show everything).
    /// </summary>
    [ObservableProperty]
    private ObservableCollection<string> _groups = ["All"];

    /// <summary>
    /// Currently selected group chip. Null or "All" means no group filtering.
    /// </summary>
    [ObservableProperty]
    private string? _selectedGroup = "All";

    /// <summary>
    /// Full set of channels loaded from the repository for the active source filter.
    /// Group filtering is applied on top of this list to produce <see cref="Channels"/>.
    /// </summary>
    private List<Channel> _allChannelsForSource = [];

    [ObservableProperty]
    private bool _isLoading;

    /// <summary>
    /// Creates a new LiveTvViewModel.
    /// </summary>
    public LiveTvViewModel(
        IChannelRepository channelRepository,
        ISourceRepository sourceRepository,
        INavigationService navigationService,
        IPlayerController playerController)
    {
        _channelRepository = channelRepository;
        _sourceRepository = sourceRepository;
        _navigationService = navigationService;
        _playerController = playerController;
        Title = "Live TV";
        LoadCommand.Execute(null);
    }

    /// <inheritdoc />
    public void OnNavigatedTo(object? parameter) => LoadCommand.Execute(null);

    /// <inheritdoc />
    public void OnNavigatedFrom() { }

    /// <summary>
    /// Loads sources and channels. Triggered on construction and when source filter changes.
    /// </summary>
    [RelayCommand]
    private async Task LoadAsync(CancellationToken ct)
    {
        IsLoading = true;
        try
        {
            var sources = await _sourceRepository.GetAllAsync();
            var enabledSources = sources.Where(s => s.IsEnabled).ToList();

            // Build filter chips: "All Sources" first, then one per enabled source.
            var filters = new ObservableCollection<SourceFilterItem>
            {
                new SourceFilterItem(null, "All Sources"),
            };
            foreach (var src in enabledSources)
            {
                filters.Add(new SourceFilterItem(src.Id, src.Name));
            }

            // Preserve selection if the selected source still exists.
            var currentId = SelectedSourceFilter?.SourceId;
            SourceFilters = filters;
            SelectedSourceFilter = filters.FirstOrDefault(f => f.SourceId == currentId) ?? filters.First();

            await LoadChannelsForFilterAsync(SelectedSourceFilter, enabledSources, ct);
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Called automatically by CommunityToolkit when SelectedSourceFilter changes.
    /// </summary>
    partial void OnSelectedSourceFilterChanged(SourceFilterItem? value)
    {
        if (value is null)
            return;

        // Fire-and-forget with cancellation not tracked; acceptable for filter switch.
        _ = ApplyFilterAsync(value);
    }

    /// <summary>
    /// Called automatically by CommunityToolkit when SelectedGroup changes.
    /// Re-applies the group filter over the already-loaded source channels.
    /// </summary>
    partial void OnSelectedGroupChanged(string? value)
    {
        ApplyGroupFilter(value);
    }

    private async Task ApplyFilterAsync(SourceFilterItem filter)
    {
        IsLoading = true;
        try
        {
            var sources = await _sourceRepository.GetAllAsync();
            var enabledSources = sources.Where(s => s.IsEnabled).ToList();
            await LoadChannelsForFilterAsync(filter, enabledSources, CancellationToken.None);
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async Task LoadChannelsForFilterAsync(
        SourceFilterItem filter,
        List<Source> enabledSources,
        CancellationToken ct)
    {
        IEnumerable<Channel> fetched;

        if (filter.SourceId is null)
        {
            // All Sources: single query instead of per-source N+1.
            fetched = await _channelRepository.GetAllAsync(ct);
        }
        else
        {
            fetched = await _channelRepository.GetBySourceAsync(filter.SourceId.Value, ct);
        }

        _allChannelsForSource = fetched.ToList();
        RebuildGroups(_allChannelsForSource);
        ApplyGroupFilter(SelectedGroup);
    }

    /// <summary>
    /// Rebuilds the Groups chip list from the current source-filtered channel set.
    /// Preserves the selected group when the group still exists; resets to "All" otherwise.
    /// </summary>
    private void RebuildGroups(List<Channel> channels)
    {
        var distinctGroups = channels
            .Select(c => c.GroupName)
            .Where(g => !string.IsNullOrEmpty(g))
            .Distinct()
            .OrderBy(g => g)
            .Select(g => g!)
            .ToList();

        var groupList = new ObservableCollection<string>(distinctGroups.Prepend("All"));
        var currentGroup = SelectedGroup;
        Groups = groupList;

        // Keep selection if the group still exists; otherwise fall back to "All".
        SelectedGroup = groupList.Contains(currentGroup ?? "All") ? (currentGroup ?? "All") : "All";
    }

    /// <summary>
    /// Filters <see cref="_allChannelsForSource"/> by the selected group and assigns
    /// the result to <see cref="Channels"/>.
    /// </summary>
    private void ApplyGroupFilter(string? group)
    {
        if (string.IsNullOrEmpty(group) || group == "All")
        {
            Channels = new ObservableCollection<Channel>(_allChannelsForSource);
        }
        else
        {
            Channels = new ObservableCollection<Channel>(
                _allChannelsForSource.Where(c => c.GroupName == group));
        }
    }

    /// <summary>
    /// Navigates to the player with the first available stream endpoint of the selected channel.
    /// Does nothing if the channel has no playable endpoints.
    /// </summary>
    [RelayCommand]
    private async Task SelectChannelAsync(Channel channel)
    {
        var fullChannel = await _channelRepository.GetByIdAsync(channel.Id);
        var endpoint = fullChannel?.StreamEndpoints
            .OrderBy(e => e.Priority)
            .FirstOrDefault();

        if (fullChannel is null || endpoint is null)
            return;

        var request = new PlaybackRequest(
            Url: endpoint.Url,
            ContentType: fullChannel.IsRadio ? PlaybackContentType.Radio : PlaybackContentType.LiveTv,
            Title: fullChannel.Title,
            ChannelLogoUrl: fullChannel.TvgLogo);

        await _playerController.PlayAsync(request);
    }
}
