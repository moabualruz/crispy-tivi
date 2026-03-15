using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Threading;
using Avalonia.VisualTree;

namespace Crispy.UI.Views;

/// <summary>
/// Main shell view with SplitView rail and content area.
/// </summary>
public partial class MainView : UserControl
{
    private Controls.NavigationRail? _rail;
    private Panel? _contentPanel;

    /// <summary>
    /// Creates a new MainView.
    /// </summary>
    public MainView()
    {
        InitializeComponent();

        _rail = this.FindControl<Controls.NavigationRail>("NavRail");
        _contentPanel = this.FindControl<Panel>("ContentPanel");

        if (_rail is not null)
        {
            _rail.ItemSelected += item =>
            {
                if (DataContext is ViewModels.MainViewModel vm)
                {
                    vm.SelectedNavItem = item;
                }
            };

            // Enter on a rail item → navigate AND move focus into the content area
            _rail.EnterPressed += () =>
            {
                if (DataContext is ViewModels.MainViewModel vm && _rail.SelectedItem is { } item)
                {
                    vm.SelectedNavItem = item;
                }

                // Move focus into the content area after navigation
                Dispatcher.UIThread.Post(() =>
                {
                    var tcc = this.GetVisualDescendants()
                        .OfType<TransitioningContentControl>()
                        .FirstOrDefault();
                    var target = tcc?.GetVisualDescendants()
                        .OfType<InputElement>()
                        .FirstOrDefault(el => el.Focusable && el.IsEffectivelyVisible);
                    target?.Focus(NavigationMethod.Directional);
                }, DispatcherPriority.Loaded);
            };
        }

        AttachedToVisualTree += (_, _) =>
        {
            // Block XYFocus from targeting covered content while the overlay pane
            // is open (workaround for Avalonia issue #14985).
            var splitView = this.FindControl<SplitView>("MainSplitView");
            if (splitView is not null)
            {
                splitView.PaneOpened += (_, _) => SetContentHitTest(false);
                splitView.PaneClosed += (_, _) => SetContentHitTest(true);
            }

            // Give the rail focus on first load so arrow keys work immediately.
            Dispatcher.UIThread.Post(
                () => _rail?.FocusPrimaryList(),
                DispatcherPriority.Loaded);
        };
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
                if (vm.CanGoBack)
                {
                    vm.GoBackCommand.Execute(null);
                    e.Handled = true;
                }
                break;

            case Key.Enter:
                // If focus is on a rail item, confirm and move focus into content
                if (_rail is not null)
                {
                    var focused = TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement();
                    if (focused is Visual v && v.GetVisualAncestors().OfType<Controls.NavigationRail>().Any())
                    {
                        var tcc = this.GetVisualDescendants()
                            .OfType<TransitioningContentControl>()
                            .FirstOrDefault();
                        var target = tcc?.GetVisualDescendants()
                            .OfType<InputElement>()
                            .FirstOrDefault(el => el.Focusable && el.IsEffectivelyVisible);
                        target?.Focus(NavigationMethod.Directional);
                        e.Handled = true;
                    }
                }
                break;
        }
    }

    // Prevents XYFocus from targeting content controls while the SplitView
    // overlay pane is open in front of them.
    private void SetContentHitTest(bool enabled)
    {
        if (_contentPanel is not null)
        {
            _contentPanel.IsHitTestVisible = enabled;
        }
    }
}
