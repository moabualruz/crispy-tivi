using Avalonia.Controls;

namespace Crispy.UI.Controls;

/// <summary>
/// Live EPG strip overlay — shows current and next programmes for the active channel.
/// Visible only when IsLive=true. Data comes from PlayerViewModel.CurrentProgrammeTitle etc. (PLR-33).
/// </summary>
public partial class LiveEpgStripOverlay : UserControl
{
    public LiveEpgStripOverlay()
    {
        InitializeComponent();
    }
}
