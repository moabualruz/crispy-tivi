namespace Crispy.UI.Navigation;

/// <summary>
/// Implemented by ViewModels that need navigation lifecycle hooks.
/// </summary>
public interface INavigationAware
{
    /// <summary>
    /// Called when this ViewModel is navigated to.
    /// </summary>
    void OnNavigatedTo(object? parameter);

    /// <summary>
    /// Called when navigating away from this ViewModel.
    /// </summary>
    void OnNavigatedFrom();
}
