using Avalonia.Controls;

namespace Crispy.UI.Controls;

/// <summary>
/// Code-behind for BookmarksOverlay.
/// Wire-up for jump-to and delete buttons is handled in AppShell
/// where the PlayerViewModel is available. This file is intentionally minimal.
/// </summary>
public partial class BookmarksOverlay : UserControl
{
    public BookmarksOverlay()
    {
        InitializeComponent();
    }
}
