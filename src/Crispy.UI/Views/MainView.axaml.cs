using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Markup.Xaml;
using Avalonia.Threading;
using Avalonia.VisualTree;

namespace Crispy.UI.Views;

/// <summary>
/// Main shell view with SplitView rail and content area.
/// </summary>
public partial class MainView : UserControl
{
    private Controls.NavigationRail? _rail;

    /// <summary>
    /// Creates a new MainView.
    /// </summary>
    public MainView()
    {
        InitializeComponent();

        _rail = this.FindControl<Controls.NavigationRail>("NavRail");
        if (_rail is not null)
        {
            _rail.ItemSelected += item =>
            {
                if (DataContext is ViewModels.MainViewModel vm)
                {
                    vm.SelectedNavItem = item;
                }
            };

            // Enter on a rail item → move keyboard focus into the content area
            _rail.EnterPressed += MovesFocusToContent;
        }

        // Focus the rail's primary list once the visual tree is ready
        AttachedToVisualTree += (_, _) =>
            Dispatcher.UIThread.Post(
                () => _rail?.FocusPrimaryList(),
                DispatcherPriority.Loaded);
    }

    private void OnRailPointerEntered(object? sender, PointerEventArgs e)
    {
        if (DataContext is ViewModels.MainViewModel vm)
        {
            vm.ExpandRail();
        }
    }

    private void OnRailPointerExited(object? sender, PointerEventArgs e)
    {
        if (DataContext is ViewModels.MainViewModel vm)
        {
            vm.CollapseRail();
        }
    }

    /// <inheritdoc />
    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);

        if (DataContext is not ViewModels.MainViewModel vm)
        {
            return;
        }

        switch (e.Key)
        {
            case Key.Escape:
            case Key.Back:
                // If focus is inside the content area, move it back to the rail
                if (IsFocusInContent())
                {
                    _rail?.FocusPrimaryList();
                    e.Handled = true;
                    return;
                }

                if (vm.CanGoBack)
                {
                    vm.GoBackCommand.Execute(null);
                    e.Handled = true;
                }

                break;
        }
    }

    // Moves keyboard focus to the first focusable element inside the content
    // area (the TransitioningContentControl child).
    private void MovesFocusToContent()
    {
        // Walk the visual tree to find the TransitioningContentControl
        var tcc = this.FindDescendantOfType<TransitioningContentControl>();
        if (tcc is null)
        {
            return;
        }

        // Find the first focusable descendant inside the content presenter
        var focusable = tcc
            .GetVisualDescendants()
            .OfType<InputElement>()
            .FirstOrDefault(el => el.Focusable && el.IsEffectivelyVisible);

        focusable?.Focus();
    }

    // Returns true when keyboard focus currently sits inside the content area
    // (i.e. not inside the navigation rail pane).
    private bool IsFocusInContent()
    {
        var focused = TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement() as Visual;
        if (focused is null)
        {
            return false;
        }

        return focused.GetVisualAncestors().Contains(_rail) == false
            && this.GetVisualDescendants().Contains(focused);
    }
}
