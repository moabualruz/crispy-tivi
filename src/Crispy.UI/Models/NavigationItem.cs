namespace Crispy.UI.Models;

/// <summary>
/// Represents a navigation rail item.
/// </summary>
public sealed record NavigationItem(
    string Name,
    string IconKey,
    Type ViewModelType,
    bool IsSecondary = false);
