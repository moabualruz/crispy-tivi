using System.Collections.ObjectModel;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.UI.Models;
using Crispy.UI.Navigation;

using FluentIcons.Common;

namespace Crispy.UI.ViewModels;

/// <summary>
/// Main shell ViewModel managing navigation rail and current page.
/// </summary>
public partial class MainViewModel : ViewModelBase
{
    private readonly INavigationService _navigationService;

    /// <summary>
    /// Whether the navigation rail overlay is expanded.
    /// </summary>
    [ObservableProperty]
    private bool _isRailExpanded;

    /// <summary>
    /// The currently displayed page ViewModel.
    /// </summary>
    [ObservableProperty]
    private ViewModelBase? _currentPage;

    /// <summary>
    /// The currently selected navigation item.
    /// </summary>
    [ObservableProperty]
    private NavigationItem? _selectedNavItem;

    /// <summary>
    /// Creates a new MainViewModel.
    /// </summary>
    public MainViewModel(INavigationService navigationService)
    {
        _navigationService = navigationService;
        Title = "CrispyTivi";

        PrimaryNavItems =
        [
            new NavigationItem("Home", Symbol.Home, typeof(HomeViewModel)),
            new NavigationItem("Live TV", Symbol.Live, typeof(LiveTvViewModel)),
            new NavigationItem("Movies", Symbol.MoviesAndTv, typeof(MoviesViewModel)),
            new NavigationItem("Series", Symbol.Tv, typeof(SeriesViewModel)),
            new NavigationItem("Search", Symbol.Search, typeof(SearchViewModel)),
        ];

        SecondaryNavItems =
        [
            new NavigationItem("Settings", Symbol.Settings, typeof(SettingsViewModel), IsSecondary: true),
        ];

        _navigationService.Navigated += OnNavigated;

        // Navigate to Home on startup
        _navigationService.NavigateTo<HomeViewModel>();
    }

    /// <summary>
    /// Primary navigation items (top section of rail).
    /// </summary>
    public ObservableCollection<NavigationItem> PrimaryNavItems { get; }

    /// <summary>
    /// Secondary navigation items (bottom section of rail).
    /// </summary>
    public ObservableCollection<NavigationItem> SecondaryNavItems { get; }

    /// <summary>
    /// Whether back navigation is available.
    /// </summary>
    public bool CanGoBack => _navigationService.CanGoBack;

    /// <summary>
    /// Navigates back to the previous view.
    /// </summary>
    [RelayCommand]
    private void GoBack()
    {
        _navigationService.GoBack();
    }

    /// <summary>
    /// Expands the navigation rail overlay.
    /// </summary>
    public void ExpandRail()
    {
        IsRailExpanded = true;
    }

    /// <summary>
    /// Collapses the navigation rail overlay.
    /// </summary>
    public void CollapseRail()
    {
        IsRailExpanded = false;
    }

    partial void OnSelectedNavItemChanged(NavigationItem? value)
    {
        if (value is not null)
        {
            _navigationService.NavigateTo(value.ViewModelType);
        }
    }

    private void OnNavigated(ViewModelBase viewModel)
    {
        CurrentPage = viewModel;
        OnPropertyChanged(nameof(CanGoBack));
    }
}
