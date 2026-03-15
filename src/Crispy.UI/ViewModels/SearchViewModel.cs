using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Search;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the Search screen.
/// Provides debounced full-text search via ISearchService, results grouped by type.
/// </summary>
public partial class SearchViewModel : ViewModelBase
{
    private readonly ISearchService _searchService;
    private CancellationTokenSource? _searchCts;

    [ObservableProperty]
    private string _searchQuery = string.Empty;

    [ObservableProperty]
    private ObservableCollection<SearchResultItem> _channelResults = [];

    [ObservableProperty]
    private ObservableCollection<SearchResultItem> _movieResults = [];

    [ObservableProperty]
    private ObservableCollection<SearchResultItem> _seriesResults = [];

    [ObservableProperty]
    private bool _isSearching;

    [ObservableProperty]
    private bool _hasResults;

    [ObservableProperty]
    private string? _errorMessage;

    /// <summary>
    /// Creates a new SearchViewModel.
    /// </summary>
    public SearchViewModel(ISearchService searchService)
    {
        Title = "Search";
        _searchService = searchService;
    }

    /// <summary>
    /// Called automatically by CommunityToolkit when SearchQuery changes.
    /// Implements 150ms debounce then invokes ISearchService.SearchAsync.
    /// </summary>
    partial void OnSearchQueryChanged(string value)
    {
        // Cancel any in-flight search.
        _searchCts?.Cancel();
        _searchCts?.Dispose();
        _searchCts = new CancellationTokenSource();

        _ = ExecuteSearchAsync(value, _searchCts.Token);
    }

    private async Task ExecuteSearchAsync(string query, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            ClearResults();
            return;
        }

        try
        {
            // 150ms debounce
            await Task.Delay(150, ct);

            IsSearching = true;
            ErrorMessage = null;

            var results = await _searchService.SearchAsync(query, profileId: 1, ct);

            ChannelResults = new ObservableCollection<SearchResultItem>(results.Channels);
            MovieResults = new ObservableCollection<SearchResultItem>(results.Movies);
            SeriesResults = new ObservableCollection<SearchResultItem>(results.Series);
            HasResults = results.TotalCount > 0;
        }
        catch (OperationCanceledException)
        {
            // Debounce cancellation — swallow silently.
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Search failed: {ex.Message}";
        }
        finally
        {
            if (!ct.IsCancellationRequested)
            {
                IsSearching = false;
            }
        }
    }

    private void ClearResults()
    {
        ChannelResults = [];
        MovieResults = [];
        SeriesResults = [];
        HasResults = false;
        IsSearching = false;
        ErrorMessage = null;
    }
}
