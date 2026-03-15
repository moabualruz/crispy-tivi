using Avalonia.Controls;

namespace Crispy.UI.Controls;

/// <summary>
/// Stream statistics overlay — displays codec, resolution, bitrate, FPS, latency, and packet loss.
/// Data is refreshed every second by PlayerViewModel's stats timer (PLR-33).
/// </summary>
public partial class StreamStatsOverlay : UserControl
{
    public StreamStatsOverlay()
    {
        InitializeComponent();
    }
}
