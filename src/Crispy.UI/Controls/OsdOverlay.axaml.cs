using Avalonia.Controls;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Controls;

/// <summary>
/// Code-behind for the OSD overlay.
/// Wires the live/VOD seek bar to the SeekBarHost content control
/// based on the PlayerViewModel.IsLive property.
/// </summary>
public partial class OsdOverlay : UserControl
{
    private LiveSeekBar? _liveSeekBar;
    private VodSeekBar? _vodSeekBar;

    protected override void OnDataContextChanged(EventArgs e)
    {
        base.OnDataContextChanged(e);

        if (DataContext is PlayerViewModel vm)
            WireSeekBars(vm);
    }

    private void WireSeekBars(PlayerViewModel vm)
    {
        // Use AXAML-generated field instead of FindControl (avoids name scope issues in headless)
        if (SeekBarHost is null) return;
        var host = SeekBarHost;

        if (_liveSeekBar is null)
        {
            _liveSeekBar = new LiveSeekBar();
            _liveSeekBar.SeekRequested += async (_, pos) => await vm.SeekCommand.ExecuteAsync(pos);
        }

        if (_vodSeekBar is null)
        {
            _vodSeekBar = new VodSeekBar();
            _vodSeekBar.SeekRequested += async (_, pos) => await vm.SeekCommand.ExecuteAsync(pos);
        }

        // Sync properties each state change
        vm.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName is nameof(PlayerViewModel.IsLive))
                UpdateSeekBarHost(vm, host);

            if (args.PropertyName is nameof(PlayerViewModel.Position)
                or nameof(PlayerViewModel.Duration)
                or nameof(PlayerViewModel.Chapters)
                or nameof(PlayerViewModel.BufferProgrammes))
                SyncSeekBarValues(vm);
        };

        UpdateSeekBarHost(vm, host);
        SyncSeekBarValues(vm);
    }

    private void UpdateSeekBarHost(PlayerViewModel vm, ContentControl host)
    {
        host.Content = vm.IsLive ? _liveSeekBar : _vodSeekBar;
    }

    private void SyncSeekBarValues(PlayerViewModel vm)
    {
        if (_liveSeekBar is not null)
        {
            _liveSeekBar.Position = vm.Position;
            _liveSeekBar.LiveEdge = vm.Duration == TimeSpan.Zero
                ? vm.Position
                : vm.Duration;
        }

        if (_vodSeekBar is not null)
        {
            _vodSeekBar.Position = vm.Position;
            _vodSeekBar.Duration = vm.Duration;
            _vodSeekBar.Chapters = vm.Chapters;
        }
    }
}
