using Avalonia.Controls;

namespace Crispy.UI.Controls;

/// <summary>
/// Player queue overlay — shows upcoming episodes/items with remove support.
/// Bound to PlayerViewModel.Queue. Play-next and remove actions are handled
/// via button Tag bindings and event subscription in AppShell (PLR-33).
/// </summary>
public partial class PlayerQueueOverlay : UserControl
{
    public PlayerQueueOverlay()
    {
        InitializeComponent();
    }
}
