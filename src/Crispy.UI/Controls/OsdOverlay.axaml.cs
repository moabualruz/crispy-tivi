using Avalonia;
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

    public OsdOverlay()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);

        // Re-wire if DataContext was set before the control entered the visual tree
        if (DataContext is PlayerViewModel vm)
            WireSeekBars(vm);
    }

    protected override void OnDataContextChanged(EventArgs e)
    {
        base.OnDataContextChanged(e);

        // Only wire when already attached (SeekBarHost is available)
        if (SeekBarHost is not null && DataContext is PlayerViewModel vm)
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
            if (args.PropertyName is nameof(PlayerViewModel.IsLive)
                or nameof(PlayerViewModel.IsTimeshifted))
                UpdateSeekBarHost(vm, host);

            if (args.PropertyName is nameof(PlayerViewModel.Position)
                or nameof(PlayerViewModel.Duration)
                or nameof(PlayerViewModel.Chapters)
                or nameof(PlayerViewModel.BufferProgrammes)
                or nameof(PlayerViewModel.TimeshiftBufferDuration)
                or nameof(PlayerViewModel.TimeshiftSeekOffset))
                SyncSeekBarValues(vm);
        };

        UpdateSeekBarHost(vm, host);
        SyncSeekBarValues(vm);
    }

    private void UpdateSeekBarHost(PlayerViewModel vm, ContentControl host)
    {
        // Show LiveSeekBar for both live and timeshifted modes
        host.Content = (vm.IsLive || vm.IsTimeshifted) ? _liveSeekBar : _vodSeekBar;
    }

    private void SyncSeekBarValues(PlayerViewModel vm)
    {
        if (_liveSeekBar is not null)
        {
            if (vm.IsTimeshifted && vm.TimeshiftBufferDuration > TimeSpan.Zero)
            {
                // Timeshifted: show buffer as the timeline, position within it
                _liveSeekBar.LiveEdge = vm.TimeshiftBufferDuration;
                _liveSeekBar.BufferStart = TimeSpan.Zero;
                _liveSeekBar.BufferEnd = vm.TimeshiftBufferDuration;
                // Offset is negative (e.g. -2:30), so position = buffer + offset
                _liveSeekBar.Position = vm.TimeshiftBufferDuration + vm.TimeshiftSeekOffset;
            }
            else
            {
                // Live at edge: position tracks live
                _liveSeekBar.Position = vm.Position;
                _liveSeekBar.LiveEdge = vm.Duration == TimeSpan.Zero
                    ? vm.Position
                    : vm.Duration;
                _liveSeekBar.BufferStart = TimeSpan.Zero;
                _liveSeekBar.BufferEnd = _liveSeekBar.LiveEdge;
            }

            _liveSeekBar.Programmes = vm.BufferProgrammes;
        }

        if (_vodSeekBar is not null)
        {
            _vodSeekBar.Position = vm.Position;
            _vodSeekBar.Duration = vm.Duration;
            _vodSeekBar.Chapters = vm.Chapters;
        }
    }
}
