using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the Series screen — loads VOD series from all enabled sources,
/// with optional per-source filtering.
/// Implements INavigationAware to reload data when navigated back to after a sync.
/// </summary>
public partial class SeriesViewModel : ViewModelBase, INavigationAware
{
    private readonly ISeriesRepository _seriesRepository;
    private readonly ISourceRepository _sourceRepository;

    [ObservableProperty]
    private ObservableCollection<Series> _series = [];

    [ObservableProperty]
    private ObservableCollection<SourceFilterItem> _sourceFilters = [];

    [ObservableProperty]
    private SourceFilterItem? _selectedSourceFilter;

    [ObservableProperty]
    private bool _isLoading;

    /// <summary>
    /// Creates a new SeriesViewModel and begins loading series.
    /// </summary>
    public SeriesViewModel(ISeriesRepository seriesRepository, ISourceRepository sourceRepository)
    {
        Title = "Series";
        _seriesRepository = seriesRepository;
        _sourceRepository = sourceRepository;

        _ = LoadAsync();
    }

    /// <inheritdoc />
    public void OnNavigatedTo(object? parameter) => _ = LoadAsync();

    /// <inheritdoc />
    public void OnNavigatedFrom() { }

    /// <summary>
    /// Loads sources and series. Builds source filter list first,
    /// then fetches series for the current filter selection.
    /// </summary>
    [RelayCommand]
    public async Task LoadAsync(CancellationToken ct = default)
    {
        IsLoading = true;
        try
        {
            var sources = await _sourceRepository.GetAllAsync();

            var filters = new ObservableCollection<SourceFilterItem>
            {
                new(null, "All Sources"),
            };

            foreach (var source in sources)
            {
                filters.Add(new SourceFilterItem(source.Id, source.Name));
            }

            SourceFilters = filters;

            if (SelectedSourceFilter is null)
            {
                SelectedSourceFilter = filters[0];
            }

            await FetchSeriesForFilterAsync(SelectedSourceFilter, ct);
        }
        finally
        {
            IsLoading = false;
        }
    }

    partial void OnSelectedSourceFilterChanged(SourceFilterItem? value)
    {
        if (value is not null)
        {
            _ = FetchSeriesForFilterAsync(value);
        }
    }

    private async Task FetchSeriesForFilterAsync(SourceFilterItem filter, CancellationToken ct = default)
    {
        IsLoading = true;
        try
        {
            IReadOnlyList<Series> results;

            if (filter.SourceId is null)
            {
                var all = new List<Series>();
                foreach (var f in SourceFilters)
                {
                    if (f.SourceId is not null)
                    {
                        var batch = await _seriesRepository.GetBySourceAsync(f.SourceId.Value, ct);
                        all.AddRange(batch);
                    }
                }

                results = all;
            }
            else
            {
                results = await _seriesRepository.GetBySourceAsync(filter.SourceId.Value, ct);
            }

            Series = new ObservableCollection<Series>(results);
        }
        finally
        {
            IsLoading = false;
        }
    }
}
