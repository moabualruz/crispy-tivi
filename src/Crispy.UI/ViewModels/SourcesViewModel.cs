using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Domain.Entities;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the Sources list in Settings.
/// Implements INavigationAware so the list is refreshed whenever the user
/// navigates back from the Add Source wizard.
/// </summary>
public partial class SourcesViewModel : ViewModelBase, INavigationAware
{
    private readonly ISourceRepository _sourceRepository;
    private readonly INavigationService _navigationService;

    /// <summary>
    /// Creates a new SourcesViewModel and initiates loading.
    /// </summary>
    public SourcesViewModel(
        ISourceRepository sourceRepository,
        INavigationService navigationService)
    {
        Title = "Sources";
        _sourceRepository = sourceRepository;
        _navigationService = navigationService;

        LoadCommand.Execute(null);
    }

    /// <inheritdoc />
    public void OnNavigatedTo(object? parameter) => LoadCommand.Execute(null);

    /// <inheritdoc />
    public void OnNavigatedFrom() { }

    /// <summary>
    /// The list of configured sources.
    /// </summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasNoSources))]
    private ObservableCollection<Source> _sources = [];

    /// <summary>
    /// True when no sources are configured (used for empty-state visibility).
    /// </summary>
    public bool HasNoSources => Sources.Count == 0;

    /// <summary>
    /// Whether the sources are currently loading.
    /// </summary>
    [ObservableProperty]
    private bool _isLoading;

    partial void OnSourcesChanged(ObservableCollection<Source> value)
    {
        value.CollectionChanged += (_, _) => OnPropertyChanged(nameof(HasNoSources));
    }

    /// <summary>
    /// Loads all sources from the repository.
    /// </summary>
    [RelayCommand]
    private async Task LoadAsync()
    {
        IsLoading = true;

        try
        {
            var all = await _sourceRepository.GetAllAsync();
            Sources = new ObservableCollection<Source>(all);
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Deletes the given source and removes it from the list.
    /// </summary>
    [RelayCommand]
    private async Task DeleteAsync(Source source)
    {
        await _sourceRepository.DeleteAsync(source.Id);
        Sources.Remove(source);
    }

    /// <summary>
    /// Navigates to the Add Source wizard.
    /// </summary>
    [RelayCommand]
    private void NavigateToAddSource()
    {
        _navigationService.NavigateTo<AddSourceViewModel>();
    }
}
