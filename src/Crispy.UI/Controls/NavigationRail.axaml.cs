using System.Collections;

using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
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
    /// Raised when the user presses Enter on a selected item, signalling that
    /// focus should move into the content area.
    /// </summary>
    public event Action? EnterPressed;

    /// <summary>
    /// Creates a new NavigationRail.
    /// </summary>
    public NavigationRail()
    {
        InitializeComponent();

        // Intercept arrow keys in the tunnel phase so we can break out of a
        // ListBox when the user presses Down on the last item (→ jump to
        // SecondaryList) or Up on the first item of SecondaryList (→ jump back).
        if (PrimaryList is not null && SecondaryList is not null)
        {
            PrimaryList.AddHandler(
                KeyDownEvent,
                (_, e) =>
                {
                    if (e.Key == Key.Down
                        && PrimaryList.SelectedIndex == PrimaryList.ItemCount - 1)
                    {
                        if (SecondaryList.ItemCount > 0)
                        {
                            SecondaryList.SelectedIndex = 0;
                            SecondaryList.ContainerFromIndex(0)?.Focus(NavigationMethod.Directional);
                        }

                        e.Handled = true;
                    }
                },
                handledEventsToo: false,
                routes: Avalonia.Interactivity.RoutingStrategies.Tunnel);

            SecondaryList.AddHandler(
                KeyDownEvent,
                (_, e) =>
                {
                    if (e.Key == Key.Up && SecondaryList.SelectedIndex == 0)
                    {
                        if (PrimaryList.ItemCount > 0)
                        {
                            var lastIdx = PrimaryList.ItemCount - 1;
                            PrimaryList.SelectedIndex = lastIdx;
                            PrimaryList.ContainerFromIndex(lastIdx)?.Focus(NavigationMethod.Directional);
                        }

                        e.Handled = true;
                    }
                },
                handledEventsToo: false,
                routes: Avalonia.Interactivity.RoutingStrategies.Tunnel);
        }

        if (PrimaryList is not null)
        {
            PrimaryList.SelectionChanged += (_, args) =>
            {
                if (args.AddedItems.Count > 0 && args.AddedItems[0] is NavigationItem item)
                {
                    if (SecondaryList is not null)
                    {
                        SecondaryList.SelectedItem = null;
                    }

                    SelectedItem = item;
                    ItemSelected?.Invoke(item);
                }
            };
        }

        if (SecondaryList is not null)
        {
            SecondaryList.SelectionChanged += (_, args) =>
            {
                if (args.AddedItems.Count > 0 && args.AddedItems[0] is NavigationItem item)
                {
                    if (PrimaryList is not null)
                    {
                        PrimaryList.SelectedItem = null;
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

    /// <summary>
    /// Focuses the first item in the primary list so arrow keys work
    /// immediately without requiring Tab first.
    /// </summary>
    public void FocusPrimaryList()
    {
        if (PrimaryList is null)
        {
            return;
        }

        // Select first item if nothing is selected yet
        if (PrimaryList.SelectedIndex < 0 && PrimaryList.ItemCount > 0)
        {
            PrimaryList.SelectedIndex = 0;
        }

        // Focus the selected container directly so arrow keys work immediately
        PrimaryList.Focus(NavigationMethod.Directional);
        if (PrimaryList.ContainerFromIndex(PrimaryList.SelectedIndex) is { } container)
        {
            container.Focus(NavigationMethod.Directional);
        }
    }

    /// <inheritdoc />
    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);

        if (e.Key == Key.Enter || e.Key == Key.Return)
        {
            // Fire EnterPressed so the shell can move focus to the content area
            EnterPressed?.Invoke();
            e.Handled = true;
        }
    }
}
