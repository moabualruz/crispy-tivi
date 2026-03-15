using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Markup.Xaml;

namespace Crispy.UI.Views;

/// <summary>
/// Main shell view with SplitView rail and content area.
/// </summary>
public partial class MainView : UserControl
{
    /// <summary>
    /// Creates a new MainView.
    /// </summary>
    public MainView()
    {
        InitializeComponent();
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
            case Key.Back:
            case Key.Escape:
                if (vm.CanGoBack)
                {
                    vm.GoBackCommand.Execute(null);
                    e.Handled = true;
                }
                break;
        }
    }
}
