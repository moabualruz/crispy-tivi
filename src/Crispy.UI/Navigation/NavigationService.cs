using Crispy.UI.ViewModels;

using Microsoft.Extensions.DependencyInjection;

namespace Crispy.UI.Navigation;

/// <summary>
/// Stack-based navigation service with DI-resolved ViewModels and scroll restoration.
/// </summary>
public sealed class NavigationService : INavigationService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly Stack<NavigationEntry> _backStack = new();
    private NavigationEntry? _current;

    /// <summary>
    /// Creates a new NavigationService backed by the given service provider.
    /// </summary>
    public NavigationService(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    /// <inheritdoc />
    public ViewModelBase? CurrentViewModel => _current?.ViewModel;

    /// <inheritdoc />
    public bool CanGoBack => _backStack.Count > 0;

    /// <inheritdoc />
    public event Action<ViewModelBase>? Navigated;

    /// <inheritdoc />
    public void NavigateTo<TViewModel>(object? parameter = null) where TViewModel : ViewModelBase
    {
        NavigateTo(typeof(TViewModel), parameter);
    }

    /// <inheritdoc />
    public void NavigateTo(Type viewModelType, object? parameter = null)
    {
        var viewModel = (ViewModelBase)_serviceProvider.GetRequiredService(viewModelType);

        // Save scroll position and notify current ViewModel
        if (_current is not null)
        {
            var scrollPosition = 0.0;
            if (_current.ViewModel is IScrollRestorable scrollable)
            {
                scrollPosition = scrollable.GetScrollPosition();
            }

            if (_current.ViewModel is INavigationAware currentAware)
            {
                currentAware.OnNavigatedFrom();
            }

            _backStack.Push(_current with { ScrollPosition = scrollPosition });
        }

        _current = new NavigationEntry(viewModel, 0, parameter);

        if (viewModel is INavigationAware aware)
        {
            aware.OnNavigatedTo(parameter);
        }

        Navigated?.Invoke(viewModel);
    }

    /// <inheritdoc />
    public void GoBack()
    {
        if (!CanGoBack)
        {
            return;
        }

        if (_current?.ViewModel is INavigationAware currentAware)
        {
            currentAware.OnNavigatedFrom();
        }

        var previous = _backStack.Pop();
        _current = previous;

        if (previous.ViewModel is IScrollRestorable scrollable)
        {
            scrollable.RestoreScrollPosition(previous.ScrollPosition);
        }

        if (previous.ViewModel is INavigationAware aware)
        {
            aware.OnNavigatedTo(previous.Parameter);
        }

        Navigated?.Invoke(previous.ViewModel);
    }
}
