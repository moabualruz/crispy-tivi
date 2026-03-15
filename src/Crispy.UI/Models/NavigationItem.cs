using FluentIcons.Common;

namespace Crispy.UI.Models;

/// <summary>
/// Represents a navigation rail item.
/// </summary>
public sealed record NavigationItem(
    string Name,
    Symbol Icon,
    Type ViewModelType,
    bool IsSecondary = false);
