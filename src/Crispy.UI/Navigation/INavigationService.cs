using Crispy.UI.ViewModels;

namespace Crispy.UI.Navigation;

/// <summary>
/// Stack-based navigation service with scroll restoration.
/// </summary>
public interface INavigationService
{
    /// <summary>
    /// Navigates to a ViewModel resolved from DI.
    /// </summary>
    void NavigateTo<TViewModel>(object? parameter = null) where TViewModel : ViewModelBase;

    /// <summary>
    /// Navigates to a ViewModel of the specified type resolved from DI.
    /// </summary>
    void NavigateTo(Type viewModelType, object? parameter = null);

    /// <summary>
    /// Whether back navigation is possible.
    /// </summary>
    bool CanGoBack { get; }

    /// <summary>
    /// Navigates back to the previous ViewModel.
    /// </summary>
    void GoBack();

    /// <summary>
    /// The currently active ViewModel.
    /// </summary>
    ViewModelBase? CurrentViewModel { get; }

    /// <summary>
    /// Fired after every navigation with the new ViewModel.
    /// </summary>
    event Action<ViewModelBase>? Navigated;
}
