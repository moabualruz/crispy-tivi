using System.Collections;

using Avalonia;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;

using Crispy.UI.Models;

namespace Crispy.UI.Controls;

/// <summary>
/// Vertical navigation rail with primary and secondary item sections.
/// </summary>
public partial class NavigationRail : UserControl
{
    /// <summary>
    /// Primary navigation items displayed at the top of the rail.
    /// </summary>
    public static readonly StyledProperty<IEnumerable?> PrimaryItemsProperty =
        AvaloniaProperty.Register<NavigationRail, IEnumerable?>(nameof(PrimaryItems));

    /// <summary>
    /// Secondary navigation items displayed at the bottom of the rail.
    /// </summary>
    public static readonly StyledProperty<IEnumerable?> SecondaryItemsProperty =
        AvaloniaProperty.Register<NavigationRail, IEnumerable?>(nameof(SecondaryItems));

    /// <summary>
    /// The currently selected navigation item.
    /// </summary>
    public static readonly StyledProperty<NavigationItem?> SelectedItemProperty =
        AvaloniaProperty.Register<NavigationRail, NavigationItem?>(nameof(SelectedItem), defaultBindingMode: Avalonia.Data.BindingMode.TwoWay);

    /// <summary>
    /// Whether the rail is expanded showing labels.
    /// </summary>
    public static readonly StyledProperty<bool> IsExpandedProperty =
        AvaloniaProperty.Register<NavigationRail, bool>(nameof(IsExpanded));

    /// <summary>
    /// Raised when the user selects a navigation item.
    /// </summary>
    public event Action<NavigationItem>? ItemSelected;

    /// <summary>
    /// Creates a new NavigationRail.
    /// </summary>
    public NavigationRail()
    {
        InitializeComponent();

        var primaryList = this.FindControl<ListBox>("PrimaryList");
        var secondaryList = this.FindControl<ListBox>("SecondaryList");

        if (primaryList is not null)
        {
            primaryList.SelectionChanged += (_, args) =>
            {
                if (args.AddedItems.Count > 0 && args.AddedItems[0] is NavigationItem item)
                {
                    if (secondaryList is not null)
                    {
                        secondaryList.SelectedItem = null;
                    }

                    SelectedItem = item;
                    ItemSelected?.Invoke(item);
                }
            };
        }

        if (secondaryList is not null)
        {
            secondaryList.SelectionChanged += (_, args) =>
            {
                if (args.AddedItems.Count > 0 && args.AddedItems[0] is NavigationItem item)
                {
                    if (primaryList is not null)
                    {
                        primaryList.SelectedItem = null;
                    }

                    SelectedItem = item;
                    ItemSelected?.Invoke(item);
                }
            };
        }
    }

    /// <summary>
    /// Primary navigation items displayed at the top of the rail.
    /// </summary>
    public IEnumerable? PrimaryItems
    {
        get => GetValue(PrimaryItemsProperty);
        set => SetValue(PrimaryItemsProperty, value);
    }

    /// <summary>
    /// Secondary navigation items displayed at the bottom of the rail.
    /// </summary>
    public IEnumerable? SecondaryItems
    {
        get => GetValue(SecondaryItemsProperty);
        set => SetValue(SecondaryItemsProperty, value);
    }

    /// <summary>
    /// The currently selected navigation item.
    /// </summary>
    public NavigationItem? SelectedItem
    {
        get => GetValue(SelectedItemProperty);
        set => SetValue(SelectedItemProperty, value);
    }

    /// <summary>
    /// Whether the rail is expanded showing labels.
    /// </summary>
    public bool IsExpanded
    {
        get => GetValue(IsExpandedProperty);
        set => SetValue(IsExpandedProperty, value);
    }
}
