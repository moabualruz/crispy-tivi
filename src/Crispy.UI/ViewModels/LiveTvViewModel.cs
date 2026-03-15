using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

namespace Crispy.UI.ViewModels;

/// <summary>
/// A chip item for the source selector bar.
/// null SourceId means "All Sources".
/// </summary>
public sealed record SourceFilterItem(int? SourceId, string Name);

/// <summary>
/// ViewModel for the Live TV screen.
/// Loads channels from IChannelRepository grouped / filtered by source.
/// </summary>
public partial class LiveTvViewModel : ViewModelBase
{
    private readonly IChannelRepository _channelRepository;
    private readonly ISourceRepository _sourceRepository;

    [ObservableProperty]
    private ObservableCollection<Channel> _channels = [];

    [ObservableProperty]
    private ObservableCollection<SourceFilterItem> _sourceFilters = [];

    [ObservableProperty]
    private SourceFilterItem? _selectedSourceFilter;

    [ObservableProperty]
    private bool _isLoading;

    /// <summary>
    /// Creates a new LiveTvViewModel.
    /// </summary>
    public LiveTvViewModel(IChannelRepository channelRepository, ISourceRepository sourceRepository)
    {
        _channelRepository = channelRepository;
        _sourceRepository = sourceRepository;
        Title = "Live TV";
        LoadCommand.Execute(null);
    }

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
            // All Sources: load from each enabled source and union results.
            var tasks = enabledSources.Select(s => _channelRepository.GetBySourceAsync(s.Id, ct));
            var results = await Task.WhenAll(tasks);
            fetched = results.SelectMany(r => r);
        }
        else
        {
            fetched = await _channelRepository.GetBySourceAsync(filter.SourceId.Value, ct);
        }

        Channels = new ObservableCollection<Channel>(fetched);
    }
}
