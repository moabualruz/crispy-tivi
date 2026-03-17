using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Controls;

/// <summary>
/// Sleep timer duration picker panel inside the OSD overlay.
/// Shows preset durations (15m, 30m, 45m, 1h, 2h) and a cancel button when active.
/// Tapping the backdrop dismisses the panel.
/// </summary>
public partial class SleepTimerPanel : UserControl
{
    public SleepTimerPanel()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        WireBackdropDismiss();
    }

    private void WireBackdropDismiss()
    {
        if (Backdrop is null) return;
        Backdrop.PointerPressed -= OnBackdropPressed;
        Backdrop.PointerPressed += OnBackdropPressed;
    }

    private void OnBackdropPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is PlayerViewModel vm)
            vm.CloseSleepTimerPanelCommand.Execute(null);
    }
}
