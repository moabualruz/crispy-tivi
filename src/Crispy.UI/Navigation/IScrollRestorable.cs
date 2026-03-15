namespace Crispy.UI.Navigation;

/// <summary>
/// Implemented by ViewModels that manage scrollable content and want scroll restoration on back navigation.
/// </summary>
public interface IScrollRestorable
{
    /// <summary>
    /// Gets the current scroll position.
    /// </summary>
    double GetScrollPosition();

    /// <summary>
    /// Restores the scroll position.
    /// </summary>
    void RestoreScrollPosition(double position);
}
