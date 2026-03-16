using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Threading;
using Avalonia.VisualTree;

using Crispy.UI.Controls;
using Crispy.UI.ViewModels;

namespace Crispy.UI.Views;

/// <summary>
/// Code-behind for the full-screen player.
/// Responsibilities (visual concerns only per MVVM):
/// — Inject OsdOverlay via OverlayLayer (airspace workaround for NativeControlHost).
/// — Wire VideoView.MediaPlayer from VlcPlayerService via reflection (keeps Crispy.UI
///   free of a direct LibVLCSharp reference; VlcPlayerService exposes MediaPlayer as object).
/// — Route keyboard shortcuts to PlayerViewModel commands (PLR-21).
/// — Detect and route touch gestures to ViewModel commands.
/// — Hide/restore cursor on Desktop when OSD is hidden.
/// — Manage dedicated FullscreenPlayerWindow on Desktop (reparents VideoSurface).
/// </summary>
public partial class PlayerView : UserControl
{
    private OsdOverlay? _osdOverlay;
    private FullscreenPlayerWindow? _fullscreenWindow;

    private static bool IsDesktop =>
        OperatingSystem.IsWindows() || OperatingSystem.IsLinux() || OperatingSystem.IsMacOS();

    // Touch gesture tracking
    private Point _gestureStart;
    private bool _gestureActive;
    private DateTime _lastTapTime;
    private Point _lastTapPoint;

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);

        if (DataContext is not PlayerViewModel vm) return;

        // Wire VideoView.MediaPlayer via reflection so Crispy.UI has no direct
        // LibVLCSharp reference. VlcPlayerService exposes a "MediaPlayer" property
        // that returns LibVLCSharp.Shared.MediaPlayer when the package is available.
        // When the package is absent (NuGet restore pending) the reflection call
        // returns null and this block is a no-op.
        WireVideoViewIfAvailable(vm);

        // OSD overlay via OverlayLayer — sits above the NativeControlHost airspace
        var overlayLayer = OverlayLayer.GetOverlayLayer(this);
        if (overlayLayer is not null)
        {
            _osdOverlay = new OsdOverlay { DataContext = DataContext };
            overlayLayer.Children.Add(_osdOverlay);
        }

        // Keyboard focus
        Focusable = true;
        Focus();
    }

    private void WireVideoViewIfAvailable(PlayerViewModel vm)
    {
        // Attempt to create a LibVLCSharp.Avalonia.VideoView via reflection.
        // This keeps the UI project free of a compile-time LibVLCSharp dependency.
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

        // Now add to visual tree — VideoView will attach its native surface to the MediaPlayer
        if (VideoSurface is not null)
            VideoSurface.Child = videoView;
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);

        if (_osdOverlay is not null)
        {
            OverlayLayer.GetOverlayLayer(this)?.Children.Remove(_osdOverlay);
            _osdOverlay = null;
        }
    }

    // ─── Pointer events — OSD + gesture detection ────────────────────────────

    protected override void OnPointerMoved(PointerEventArgs e)
    {
        base.OnPointerMoved(e);

        if (DataContext is PlayerViewModel vm)
            vm.ShowOsd();

        // Restore cursor on Desktop
        Cursor = Cursor.Default;

        // Gesture tracking (touch)
        if (_gestureActive && e.Pointer.Captured == this)
        {
            var current = e.GetPosition(this);
            var delta = current - _gestureStart;
            if (DataContext is PlayerViewModel gvm)
                HandleGestureDelta(gvm, delta, current);
        }
    }

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        _gestureStart = e.GetPosition(this);

        // Double-tap detection (PLR-20)
        var now = DateTime.UtcNow;
        var tapPos = _gestureStart;
        if ((now - _lastTapTime).TotalMilliseconds < 350
            && Math.Abs(tapPos.X - _lastTapPoint.X) < 80)
        {
            if (DataContext is PlayerViewModel vm)
                HandleDoubleTap(vm, tapPos);
        }
        _lastTapTime = now;
        _lastTapPoint = tapPos;

        if (e.Pointer.Type == PointerType.Touch)
        {
            _gestureActive = true;
            e.Pointer.Capture(this);
        }

        if (DataContext is PlayerViewModel ovm)
            ovm.ShowOsd();
    }

    protected override void OnPointerReleased(PointerReleasedEventArgs e)
    {
        base.OnPointerReleased(e);
        _gestureActive = false;
        e.Pointer.Capture(null);
    }

    private void HandleDoubleTap(PlayerViewModel vm, Point tapPos)
    {
        // Double-tap left third → seek -10s, right third → seek +10s (PLR-20)
        var w = Bounds.Width;
        if (tapPos.X < w / 3)
            _ = vm.SeekCommand.ExecuteAsync(vm.Position - TimeSpan.FromSeconds(10));
        else if (tapPos.X > 2 * w / 3)
            _ = vm.SeekCommand.ExecuteAsync(vm.Position + TimeSpan.FromSeconds(10));
    }

    private void HandleGestureDelta(PlayerViewModel vm, Vector delta, Point current)
    {
        var w = Bounds.Width;
        var absX = Math.Abs(delta.X);
        var absY = Math.Abs(delta.Y);

        if (absX > absY && absX > 10)
        {
            // Horizontal swipe → seek (PLR-18)
            var seekDelta = TimeSpan.FromSeconds(delta.X / w * 120);
            _ = vm.SeekCommand.ExecuteAsync(vm.Position + seekDelta);
        }
        else if (absY > absX && absY > 10)
        {
            if (current.X > w / 2)
            {
                // Right-half vertical swipe → volume (PLR-17)
                var volDelta = (float)(-delta.Y / Bounds.Height);
                _ = vm.SetVolumeCommand.ExecuteAsync(Math.Clamp(vm.Volume + volDelta, 0f, 1f));
            }
            // Left-half vertical swipe → brightness (PLR-17, platform-specific)
        }
    }

    // ─── Keyboard shortcuts (PLR-21) ─────────────────────────────────────────

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (DataContext is not PlayerViewModel vm) return;

        switch (e.Key)
        {
            case Key.Space:
                if (vm.IsPlaying) vm.PauseCommand.Execute(null);
                else vm.ResumeCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.F:
                if (IsDesktop)
                    ToggleFullscreenWindow();
                else
                    vm.ToggleFullscreenCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.M:
                vm.ToggleMuteCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.Up:
                _ = vm.SetVolumeCommand.ExecuteAsync(Math.Clamp(vm.Volume + 0.05f, 0f, 1f));
                e.Handled = true;
                break;

            case Key.Down:
                _ = vm.SetVolumeCommand.ExecuteAsync(Math.Clamp(vm.Volume - 0.05f, 0f, 1f));
                e.Handled = true;
                break;

            case Key.Left:
                var seekBack = e.KeyModifiers.HasFlag(KeyModifiers.Shift)
                    ? TimeSpan.FromSeconds(-60)
                    : TimeSpan.FromSeconds(-10);
                _ = vm.SeekCommand.ExecuteAsync(vm.Position + seekBack);
                e.Handled = true;
                break;

            case Key.Right:
                var seekFwd = e.KeyModifiers.HasFlag(KeyModifiers.Shift)
                    ? TimeSpan.FromSeconds(60)
                    : TimeSpan.FromSeconds(10);
                _ = vm.SeekCommand.ExecuteAsync(vm.Position + seekFwd);
                e.Handled = true;
                break;

            case Key.Escape:
                if (IsDesktop && _fullscreenWindow is not null)
                    ExitFullscreenWindow();
                else
                    vm.ToggleFullscreenCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.A:
                _ = CycleAudioTrackAsync(vm);
                e.Handled = true;
                break;

            case Key.S:
                vm.OpenTrackSelectorCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.C:
                vm.CycleSubtitleTrackCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.N:
                vm.NextEpisodeCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.B:
                vm.AddBookmarkCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.E:
                vm.OpenEqualizerCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.OemPeriod when e.KeyModifiers.HasFlag(KeyModifiers.Shift): // >
                vm.IncreaseSpeedCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.OemComma when e.KeyModifiers.HasFlag(KeyModifiers.Shift): // <
                vm.DecreaseSpeedCommand.Execute(null);
                e.Handled = true;
                break;

            case Key.Back:
                vm.PreviousChannelCommand.Execute(null);
                e.Handled = true;
                break;

            default:
                // Digit keys 0-9 for direct tune
                if (e.Key >= Key.D0 && e.Key <= Key.D9)
                {
                    vm.HandleDigitKey(((int)(e.Key - Key.D0)).ToString());
                    e.Handled = true;
                }
                else if (e.Key >= Key.NumPad0 && e.Key <= Key.NumPad9)
                {
                    vm.HandleDigitKey(((int)(e.Key - Key.NumPad0)).ToString());
                    e.Handled = true;
                }
                break;
        }

        vm.ShowOsd();
    }

    // ─── Dedicated fullscreen window (Desktop only) ───────────────────────────

    private void ToggleFullscreenWindow()
    {
        if (_fullscreenWindow is null)
            EnterFullscreenWindow();
        else
            ExitFullscreenWindow();
    }

    private void EnterFullscreenWindow()
    {
        if (VideoSurface is null) return;

        // Detach VideoSurface from this view
        VideoSurface.IsVisible = false;
        var surface = VideoSurface;

        _fullscreenWindow = new FullscreenPlayerWindow();
        _fullscreenWindow.SetVideoContent(surface);
        _fullscreenWindow.ExitRequested += (_, _) => ExitFullscreenWindow();
        _fullscreenWindow.Show();
        _fullscreenWindow.Focus();

        // Move OSD into the fullscreen window's overlay layer
        if (_osdOverlay is not null)
        {
            OverlayLayer.GetOverlayLayer(this)?.Children.Remove(_osdOverlay);
            var fsOverlay = OverlayLayer.GetOverlayLayer(_fullscreenWindow);
            fsOverlay?.Children.Add(_osdOverlay);
        }
    }

    private void ExitFullscreenWindow()
    {
        if (_fullscreenWindow is null) return;

        // Move OSD back to PlayerView overlay
        if (_osdOverlay is not null)
        {
            OverlayLayer.GetOverlayLayer(_fullscreenWindow)?.Children.Remove(_osdOverlay);
            OverlayLayer.GetOverlayLayer(this)?.Children.Add(_osdOverlay);
        }

        _fullscreenWindow.DetachVideoContent();

        if (VideoSurface is not null)
            VideoSurface.IsVisible = true;

        var win = _fullscreenWindow;
        _fullscreenWindow = null;
        win.Close();

        // Return focus to this view
        Focus();
    }

    private static int FindIndex<T>(IReadOnlyList<T> list, Func<T, bool> predicate)
    {
        for (var i = 0; i < list.Count; i++)
            if (predicate(list[i])) return i;
        return -1;
    }

    private static async Task CycleAudioTrackAsync(PlayerViewModel vm)
    {
        var tracks = vm.AudioTracks;
        if (tracks.Count == 0) return;
        var current = tracks.FirstOrDefault(t => t.IsSelected);
        var currentIdx = current is null ? -1 : FindIndex(tracks, t => t.Id == current.Id);
        var idx = currentIdx < 0 ? 0 : (currentIdx + 1) % tracks.Count;
        await vm.PlayerService.SetAudioTrackAsync(tracks[idx].Id);
    }
}
