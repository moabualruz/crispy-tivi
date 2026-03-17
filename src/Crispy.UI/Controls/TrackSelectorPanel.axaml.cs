using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;

using Crispy.UI.ViewModels;
using Crispy.UI.Views;

namespace Crispy.UI.Controls;

/// <summary>
/// Slide-from-right panel hosting the TrackSelectorView inside the OSD overlay.
/// Wires TrackSelectorViewModel data from the parent PlayerViewModel's current state.
/// Tapping the backdrop dismisses the panel.
/// </summary>
public partial class TrackSelectorPanel : UserControl
{
    private TrackSelectorView? _trackSelectorView;
    private TrackSelectorViewModel? _trackSelectorViewModel;

    public TrackSelectorPanel()
    {
        InitializeComponent();
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        WireContent();
        WireBackdropDismiss();
    }

    protected override void OnDataContextChanged(EventArgs e)
    {
        base.OnDataContextChanged(e);
        WireContent();
    }

    private void WireContent()
    {
        if (TrackSelectorHost is null || DataContext is not PlayerViewModel vm)
            return;

        if (_trackSelectorViewModel is null)
        {
            _trackSelectorViewModel = new TrackSelectorViewModel(vm.PlayerService);
            _trackSelectorView = new TrackSelectorView { DataContext = _trackSelectorViewModel };
            TrackSelectorHost.Content = _trackSelectorView;
        }

        // Sync current state into the track selector VM
        _trackSelectorViewModel.UpdateFromState(vm.PlayerService.State);

        // Listen for future state changes to keep tracks synced while panel is open
        vm.PropertyChanged -= OnPlayerPropertyChanged;
        vm.PropertyChanged += OnPlayerPropertyChanged;
    }

    private void OnPlayerPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(PlayerViewModel.AudioTracks)
            or nameof(PlayerViewModel.SubtitleTracks)
            or nameof(PlayerViewModel.Rate)
            or nameof(PlayerViewModel.IsLive))
        {
            if (DataContext is PlayerViewModel vm && _trackSelectorViewModel is not null)
                _trackSelectorViewModel.UpdateFromState(vm.PlayerService.State);
        }
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
            vm.CloseTrackSelectorCommand.Execute(null);
    }
}
