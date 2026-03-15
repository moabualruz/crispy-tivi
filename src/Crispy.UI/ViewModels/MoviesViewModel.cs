using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the Movies screen — loads VOD movies from all enabled sources,
/// with optional per-source filtering.
/// </summary>
public partial class MoviesViewModel : ViewModelBase
{
    private readonly IMovieRepository _movieRepository;
    private readonly ISourceRepository _sourceRepository;

    [ObservableProperty]
    private ObservableCollection<Movie> _movies = [];

    [ObservableProperty]
    private ObservableCollection<SourceFilterItem> _sourceFilters = [];

    [ObservableProperty]
    private SourceFilterItem? _selectedSourceFilter;

    [ObservableProperty]
    private bool _isLoading;

    /// <summary>
    /// Creates a new MoviesViewModel and begins loading movies.
    /// </summary>
    public MoviesViewModel(IMovieRepository movieRepository, ISourceRepository sourceRepository)
    {
        Title = "Movies";
        _movieRepository = movieRepository;
        _sourceRepository = sourceRepository;

        _ = LoadAsync();
    }

    /// <summary>
    /// Loads sources and movies. Builds source filter list first,
    /// then fetches movies for the current filter selection.
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

            await FetchMoviesForFilterAsync(SelectedSourceFilter, ct);
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
            _ = FetchMoviesForFilterAsync(value);
        }
    }

    private async Task FetchMoviesForFilterAsync(SourceFilterItem filter, CancellationToken ct = default)
    {
        IsLoading = true;
        try
        {
            IReadOnlyList<Movie> results;

            if (filter.SourceId is null)
            {
                var all = new List<Movie>();
                foreach (var f in SourceFilters)
                {
                    if (f.SourceId is not null)
                    {
                        var batch = await _movieRepository.GetBySourceAsync(f.SourceId.Value, ct);
                        all.AddRange(batch);
                    }
                }

                results = all;
            }
            else
            {
                results = await _movieRepository.GetBySourceAsync(filter.SourceId.Value, ct);
            }

            Movies = new ObservableCollection<Movie>(results);
        }
        finally
        {
            IsLoading = false;
        }
    }
}
