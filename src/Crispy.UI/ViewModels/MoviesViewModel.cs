using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player.Models;
using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the Movies screen — loads VOD movies from all enabled sources,
/// with optional per-source filtering.
/// Implements INavigationAware to reload data when navigated back to after a sync.
/// </summary>
public partial class MoviesViewModel : ViewModelBase, INavigationAware
{
    private readonly IMovieRepository _movieRepository;
    private readonly ISourceRepository _sourceRepository;
    private readonly INavigationService _navigationService;
    private readonly IPlayerController _playerController;

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
    public MoviesViewModel(
        IMovieRepository movieRepository,
        ISourceRepository sourceRepository,
        INavigationService navigationService,
        IPlayerController playerController)
    {
        Title = "Movies";
        _movieRepository = movieRepository;
        _sourceRepository = sourceRepository;
        _navigationService = navigationService;
        _playerController = playerController;

        _ = LoadAsync();
    }

    /// <summary>
    /// Triggers playback for the selected movie.
    /// No-ops when <paramref name="movie"/> has no stream URL.
    /// </summary>
    [RelayCommand]
    private async Task SelectMovieAsync(Movie movie)
    {
        if (string.IsNullOrEmpty(movie.StreamUrl))
            return;

        var request = new PlaybackRequest(
            Url: movie.StreamUrl,
            ContentType: PlaybackContentType.Vod,
            Title: movie.Title);

        await _playerController.PlayAsync(request);
    }

    /// <inheritdoc />
    public void OnNavigatedTo(object? parameter) => _ = LoadAsync();

    /// <inheritdoc />
    public void OnNavigatedFrom() { }

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
                results = await _movieRepository.GetAllAsync(ct);
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
