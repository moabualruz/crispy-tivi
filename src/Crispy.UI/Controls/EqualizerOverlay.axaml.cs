using Avalonia.Controls;

namespace Crispy.UI.Controls;

/// <summary>
/// Equalizer overlay — 10-band graphic EQ with preset selector.
/// DataContext must be set to EqualizerOverlayViewModel by the parent (PlayerView).
/// EQ band slider changes propagate to IEqualizerService via EqBandViewModel.GainDb
/// two-way binding (PLR-33).
/// </summary>
public partial class EqualizerOverlay : UserControl
{
    public EqualizerOverlay()
    {
        InitializeComponent();
    }
}
