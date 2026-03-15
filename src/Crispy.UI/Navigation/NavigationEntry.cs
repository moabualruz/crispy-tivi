using Crispy.UI.ViewModels;

namespace Crispy.UI.Navigation;

/// <summary>
/// Represents a navigation back-stack entry with scroll position.
/// </summary>
public sealed record NavigationEntry(
    ViewModelBase ViewModel,
    double ScrollPosition,
    object? Parameter);
