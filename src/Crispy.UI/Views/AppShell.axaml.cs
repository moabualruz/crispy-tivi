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
/// — Wire VideoView.MediaPlayer to VlcPlayerService.NativePlayerHandle at startup.
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

            // On desktop, wrap OverlayContent in a LibVLCSharp.Avalonia.VideoView
            // for NativeControlHost airspace fix. On Android/iOS/Browser, skip —
            // Avalonia renders via Skia directly, no airspace issue.
            if (DataContext is AppShellViewModel shellVm)
            {
                if (!OperatingSystem.IsAndroid() && !OperatingSystem.IsIOS() && !OperatingSystem.IsBrowser())
                {
                    Dispatcher.UIThread.Post(() =>
                    {
                        var videoLayer = this.FindControl<Panel>("VideoLayer");
                        var overlayContent = this.FindControl<Grid>("OverlayContent");
                        if (videoLayer is not null && overlayContent is not null)
                        {
                            var videoView = new LibVLCSharp.Avalonia.VideoView();
                            videoLayer.Children.Remove(overlayContent);
                            videoView.Content = overlayContent;
                            videoLayer.Children.Add(videoView);

                            if (shellVm.Player.PlayerService.NativePlayerHandle
                                is LibVLCSharp.Shared.MediaPlayer mp)
                            {
                                videoView.MediaPlayer = mp;
                            }
                        }
                    }, DispatcherPriority.Loaded);
                }

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

    /// <summary>Volume step applied per Up/Down key press (5%).</summary>
    private const float VolumeStep = 0.05f;

    /// <summary>Seek step applied per Left/Right key press (10 seconds).</summary>
    private static readonly TimeSpan SeekStep = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Derives the current <see cref="Crispy.Application.Services.AppState"/>
    /// from the AppShellViewModel's layer visibility flags.
    /// </summary>
    private static Application.Services.AppState GetAppState(AppShellViewModel vm)
    {
        if (vm.IsVideoVisible && !vm.IsContentVisible)
            return Application.Services.AppState.Watching;
        if (vm.IsVideoVisible && vm.IsContentVisible)
            return Application.Services.AppState.BrowsingWhilePlaying;
        return Application.Services.AppState.Browsing;
    }

    /// <inheritdoc />
    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);

        if (DataContext is not AppShellViewModel vm)
            return;

        var appState = GetAppState(vm);
        var isWatching = appState is Application.Services.AppState.Watching
            or Application.Services.AppState.BrowsingWhilePlaying;

        switch (e.Key)
        {
            // ── Player shortcuts (only when watching) ───────────────────────
            case Key.Space when isWatching:
                if (vm.Player.IsPlaying)
                    vm.Player.PauseCommand.Execute(null);
                else
                    vm.Player.ResumeCommand.Execute(null);
                e.Handled = true;
                break;

            // ── Multiview toggle (Ctrl+M — must precede plain M/mute) ──
            case Key.M when isWatching && e.KeyModifiers.HasFlag(KeyModifiers.Control):
                if (vm.Player.IsMultiviewActive)
                    vm.Player.DeactivateMultiviewCommand.Execute(null);
                else
                    vm.Player.ActivateMultiviewCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.M when isWatching:
                vm.Player.ToggleMuteCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.A when isWatching:
                vm.Player.CycleAudioTrackCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.S when isWatching:
                vm.Player.CycleSubtitleTrackCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.Up when isWatching && appState is Application.Services.AppState.Watching:
                var volUp = Math.Min(1.0f, vm.Player.Volume + VolumeStep);
                vm.Player.SetVolumeCommand.Execute(volUp);
                e.Handled = true;
                break;

            case Key.Down when isWatching && appState is Application.Services.AppState.Watching:
                var volDown = Math.Max(0.0f, vm.Player.Volume - VolumeStep);
                vm.Player.SetVolumeCommand.Execute(volDown);
                e.Handled = true;
                break;

            case Key.Left when appState is Application.Services.AppState.Watching:
                var seekBack = vm.Player.Position - SeekStep;
                if (seekBack < TimeSpan.Zero) seekBack = TimeSpan.Zero;
                vm.Player.SeekCommand.Execute(seekBack);
                e.Handled = true;
                break;

            case Key.Right when appState is Application.Services.AppState.Watching:
                var seekFwd = vm.Player.Position + SeekStep;
                if (seekFwd > vm.Player.Duration) seekFwd = vm.Player.Duration;
                vm.Player.SeekCommand.Execute(seekFwd);
                e.Handled = true;
                break;

            // ── Fullscreen toggle ───────────────────────────────────────────
            case Key.F:
                vm.ToggleFullscreenCommand.Execute(null);
                e.Handled = true;
                break;

            // ── Escape / Back ───────────────────────────────────────────────
            case Key.Escape:
            case Key.Back:
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

            // ── Enter on rail → confirm + focus content ─────────────────────
            case Key.Enter:
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

    // ─── XYFocus workaround ───────────────────────────────────────────────────

    // Prevents XYFocus from targeting content controls while the SplitView
    // overlay pane is open in front of them.
    private void SetContentHitTest(bool enabled)
    {
        if (_contentPanel is not null)
            _contentPanel.IsHitTestVisible = enabled;
    }
}
