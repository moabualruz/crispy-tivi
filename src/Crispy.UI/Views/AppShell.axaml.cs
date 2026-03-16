using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Threading;
using Avalonia.VisualTree;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Views;

/// <summary>
/// Code-behind for the AppShell root view.
/// Responsibilities (visual concerns only per MVVM):
/// — Route keyboard shortcuts (Escape, Back, Enter) to Navigation/Player commands.
/// — Manage pointer-based rail expand/collapse.
/// — Prevent XYFocus from targeting covered content during SplitView overlay.
/// — Wire VideoView.MediaPlayer from VlcPlayerService via reflection (temporary —
///   Phase B replaces with GpuVideoSurface).
/// — Create VideoView once on first attach; never destroy it.
/// — Fullscreen: listen to IsFullscreen on ViewModel, toggle WindowState + title bar.
/// </summary>
public partial class AppShell : UserControl
{
    private Controls.NavigationRail? _rail;
    private Panel? _contentPanel;
    private AppShellViewModel? _subscribedVm;

    /// <summary>Creates a new AppShell.</summary>
    public AppShell()
    {
        InitializeComponent();

        _rail = this.FindControl<Controls.NavigationRail>("NavRail");
        _contentPanel = this.FindControl<Panel>("ContentPanel");

        if (_rail is not null)
        {
            _rail.ItemSelected += item =>
            {
                if (DataContext is AppShellViewModel vm)
                {
                    vm.Navigation.SelectedNavItem = item;
                }
            };

            // Enter on a rail item → navigate AND move focus into the content area
            _rail.EnterPressed += () =>
            {
                if (DataContext is AppShellViewModel vm && _rail.SelectedItem is { } item)
                {
                    vm.Navigation.SelectedNavItem = item;
                }

                // Move focus into the content area after navigation
                Dispatcher.UIThread.Post(() =>
                {
                    var tcc = this.GetVisualDescendants()
                        .OfType<TransitioningContentControl>()
                        .FirstOrDefault();
                    var target = tcc?.GetVisualDescendants()
                        .OfType<InputElement>()
                        .FirstOrDefault(el => el.Focusable && el.IsEffectivelyVisible);
                    target?.Focus(NavigationMethod.Directional);
                }, DispatcherPriority.Loaded);
            };
        }

        AttachedToVisualTree += (_, _) =>
        {
            // Block XYFocus from targeting covered content while the overlay pane
            // is open (workaround for Avalonia XYFocus traversal).
            var splitView = this.FindControl<SplitView>("MainSplitView");
            if (splitView is not null)
            {
                splitView.PaneOpened += (_, _) => SetContentHitTest(false);
                splitView.PaneClosed += (_, _) => SetContentHitTest(true);
            }

            // Give the rail focus on first load so arrow keys work immediately.
            Dispatcher.UIThread.Post(
                () => _rail?.FocusPrimaryList(),
                DispatcherPriority.Loaded);

            // Wire VideoView once — lives for the session lifetime.
            // Deferred to DispatcherPriority.Loaded so the native window handle
            // exists before NativeControlHost tries to create a child window.
            if (DataContext is AppShellViewModel shellVm)
            {
                Dispatcher.UIThread.Post(
                    () => WireVideoViewIfAvailable(shellVm.Player),
                    DispatcherPriority.Loaded);
                SubscribeFullscreen(shellVm);
            }
        };

        DataContextChanged += (_, _) =>
        {
            if (_subscribedVm is not null)
            {
                _subscribedVm.PropertyChanged -= OnViewModelPropertyChanged;
                _subscribedVm = null;
            }
            if (DataContext is AppShellViewModel newVm)
                SubscribeFullscreen(newVm);
        };
    }

    // ─── Fullscreen wiring ────────────────────────────────────────────────────

    private void SubscribeFullscreen(AppShellViewModel vm)
    {
        if (_subscribedVm is not null)
            _subscribedVm.PropertyChanged -= OnViewModelPropertyChanged;
        _subscribedVm = vm;
        _subscribedVm.PropertyChanged += OnViewModelPropertyChanged;
    }

    private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is not nameof(AppShellViewModel.IsFullscreen)) return;
        if (sender is not AppShellViewModel vm) return;

        var window = TopLevel.GetTopLevel(this) as Window;
        if (window is null) return;

        if (vm.IsFullscreen)
        {
            window.WindowState = WindowState.FullScreen;
            window.SystemDecorations = SystemDecorations.None;
        }
        else
        {
            window.WindowState = WindowState.Normal;
            window.SystemDecorations = SystemDecorations.Full;
        }
    }

    // ─── Rail pointer handlers ────────────────────────────────────────────────

    private void OnRailPointerEntered(object? sender, PointerEventArgs e)
    {
        if (DataContext is AppShellViewModel vm)
            vm.Navigation.ExpandRail();
    }

    private void OnRailPointerExited(object? sender, PointerEventArgs e)
    {
        if (DataContext is AppShellViewModel vm)
            vm.Navigation.CollapseRail();
    }

    // ─── Keyboard routing ─────────────────────────────────────────────────────

    /// <inheritdoc />
    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);

        if (DataContext is not AppShellViewModel vm)
            return;

        switch (e.Key)
        {
            case Key.F:
                vm.ToggleFullscreenCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.Escape:
            case Key.Back:
                // Exit fullscreen first if active; otherwise go back in navigation
                if (vm.IsFullscreen)
                {
                    vm.ToggleFullscreenCommand.Execute(null);
                    e.Handled = true;
                }
                else if (vm.Navigation.CanGoBack)
                {
                    vm.Navigation.GoBackCommand.Execute(null);
                    e.Handled = true;
                }
                break;

            case Key.Enter:
                // If focus is on a rail item, confirm and move focus into content
                if (_rail is not null)
                {
                    var focused = TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement();
                    if (focused is Visual v && v.GetVisualAncestors().OfType<Controls.NavigationRail>().Any())
                    {
                        var tcc = this.GetVisualDescendants()
                            .OfType<TransitioningContentControl>()
                            .FirstOrDefault();
                        var target = tcc?.GetVisualDescendants()
                            .OfType<InputElement>()
                            .FirstOrDefault(el => el.Focusable && el.IsEffectivelyVisible);
                        target?.Focus(NavigationMethod.Directional);
                        e.Handled = true;
                    }
                }
                break;
        }
    }

    // ─── VideoView wiring (temporary — Phase B replaces with GpuVideoSurface) ─

    /// <summary>
    /// Creates LibVLCSharp.Avalonia.VideoView via reflection and places it in VideoLayer.
    /// Keeps Crispy.UI free of a compile-time LibVLCSharp dependency.
    /// Called once on first attach — the VideoView is never destroyed.
    /// </summary>
    private void WireVideoViewIfAvailable(PlayerViewModel vm)
    {
        var videoViewType = Type.GetType(
            "LibVLCSharp.Avalonia.VideoView, LibVLCSharp.Avalonia",
            throwOnError: false);
        if (videoViewType is null) return;

        if (Activator.CreateInstance(videoViewType) is not Control videoView) return;

        videoView.SetValue(HorizontalAlignmentProperty, Avalonia.Layout.HorizontalAlignment.Stretch);
        videoView.SetValue(VerticalAlignmentProperty, Avalonia.Layout.VerticalAlignment.Stretch);

        // Assign MediaPlayer BEFORE adding to tree — LibVLCSharp.Avalonia.VideoView
        // hooks into the MediaPlayer to provide the rendering surface. This must happen
        // BEFORE Play() is called, otherwise VLC creates its own output window.
        var mpFromService = vm.PlayerService.GetType()
            .GetProperty("MediaPlayer")
            ?.GetValue(vm.PlayerService);
        if (mpFromService is not null)
        {
            videoViewType.GetProperty("MediaPlayer")?.SetValue(videoView, mpFromService);
        }

        // Place the VideoView inside VideoLayer (Border in Layer 0)
        var videoLayer = this.FindControl<Border>("VideoLayer");
        if (videoLayer is not null)
            videoLayer.Child = videoView;
    }

    // ─── XYFocus workaround ───────────────────────────────────────────────────

    // Prevents XYFocus from targeting content controls while the SplitView
    // overlay pane is open in front of them.
    private void SetContentHitTest(bool enabled)
    {
        if (_contentPanel is not null)
            _contentPanel.IsHitTestVisible = enabled;
    }
}
