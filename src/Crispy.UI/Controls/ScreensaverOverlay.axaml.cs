using Avalonia.Controls;
using Avalonia.Input;

namespace Crispy.UI.Controls;

/// <summary>
/// Screensaver overlay — activates after inactivity timeout; dismissed by any input.
/// PlayerViewModel.IsScreensaverActive controls visibility. Any PointerPressed on
/// this overlay dismisses it via ResetScreensaverTimer() on the bound ViewModel (PLR-33).
/// </summary>
public partial class ScreensaverOverlay : UserControl
{
    public ScreensaverOverlay()
    {
        InitializeComponent();
        PointerPressed += OnPointerPressed;
    }

    private void OnPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is ViewModels.PlayerViewModel vm)
        {
            vm.DismissScreensaver();
        }
    }
}
