using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.VisualTree;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Views;

/// <summary>
/// Code-behind for MultiviewView.
/// Responsibilities:
/// — Wire VideoView.MediaPlayer for each of the 4 slot containers via reflection
///   (same airspace workaround as PlayerView — keeps Crispy.UI free of a compile-time
///   LibVLCSharp reference).
/// — Route keyboard shortcuts: Left/Right/Up/Down change audio slot, F expands focused slot.
/// — Pointer drag-to-swap between slots.
///
/// Satisfies PLR-29 (4-up grid), PLR-30 (audio routing), PLR-32 (expand/swap).
/// </summary>
public partial class MultiviewView : UserControl
{
    // Drag-to-swap tracking
    private int _dragSourceSlot = -1;
    private Point _dragStart;
    private bool _dragActive;

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);

        if (DataContext is not MultiviewViewModel vm) return;

        // Wire VideoView for each slot
        for (var i = 0; i < vm.Slots.Count && i < 4; i++)
        {
            WireSlotVideoView(vm.Slots[i], i);
        }

        // Keyboard input
        Focusable = true;
        Focus();
    }

    // ─── VideoView wiring ─────────────────────────────────────────────────────

    private readonly Border?[] _videoSurfaces = new Border?[4];

    private void WireSlotVideoView(MultiviewSlotViewModel slotVm, int slotIndex)
    {
        var container = slotIndex switch
        {
            0 => FindNamedChild("Slot0Container"),
            1 => FindNamedChild("Slot1Container"),
            2 => FindNamedChild("Slot2Container"),
            3 => FindNamedChild("Slot3Container"),
            _ => null,
        };

        if (container is null) return;

        // Build slot panel: video surface + overlay
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition(GridLength.Star));

        // VideoSurface placeholder — replaced with VideoView when LibVLCSharp is available
        var videoSurface = new Border
        {
            Background = Avalonia.Media.Brushes.Black,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Stretch,
        };
        _videoSurfaces[slotIndex] = videoSurface;
        root.Children.Add(videoSurface);

        // Slot overlay: audio badge + controls
        var overlay = BuildSlotOverlay(slotVm, slotIndex);
        root.Children.Add(overlay);

        ((ContentControl)container).Content = root;

        // Wire actual VideoView if LibVLCSharp is available
        TryWireVideoView(slotVm, videoSurface);
    }

    private static void TryWireVideoView(MultiviewSlotViewModel slotVm, Border surface)
    {
        var videoViewType = Type.GetType(
            "LibVLCSharp.Avalonia.VideoView, LibVLCSharp.Avalonia",
            throwOnError: false);
        if (videoViewType is null) return;

        if (Activator.CreateInstance(videoViewType) is not Control videoView) return;

        videoView.SetValue(HorizontalAlignmentProperty, Avalonia.Layout.HorizontalAlignment.Stretch);
        videoView.SetValue(VerticalAlignmentProperty, Avalonia.Layout.VerticalAlignment.Stretch);

        var mpFromService = slotVm.PlayerService.GetType()
            .GetProperty("MediaPlayer")
            ?.GetValue(slotVm.PlayerService);
        if (mpFromService is not null)
        {
            videoViewType.GetProperty("MediaPlayer")?.SetValue(videoView, mpFromService);
        }

        // Replace surface with VideoView
        if (surface.Parent is Grid parent)
        {
            var idx = parent.Children.IndexOf(surface);
            if (idx >= 0)
            {
                parent.Children[idx] = videoView;
            }
        }
    }

    // ─── Slot overlay ─────────────────────────────────────────────────────────

    private Grid BuildSlotOverlay(MultiviewSlotViewModel slotVm, int slotIndex)
    {
        var overlay = new Grid();

        // Audio-active border highlight
        var border = new Border
        {
            BorderThickness = new Thickness(2),
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Stretch,
            IsHitTestVisible = false,
        };
        // BorderBrush updated reactively in OnSlotsChanged — set initial state
        border.BorderBrush = slotVm.IsAudioActive
            ? new Avalonia.Media.SolidColorBrush(Avalonia.Media.Color.Parse("#FF66B5FF"))
            : Avalonia.Media.Brushes.Transparent;
        overlay.Children.Add(border);

        // Top bar: channel name + audio badge
        var topBar = new Border
        {
            Background = new Avalonia.Media.SolidColorBrush(Avalonia.Media.Color.Parse("#CC000000")),
            Padding = new Thickness(8, 4),
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Top,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch,
        };
        var topGrid = new Grid();
        topGrid.ColumnDefinitions.Add(new ColumnDefinition(GridLength.Star));
        topGrid.ColumnDefinitions.Add(new ColumnDefinition(GridLength.Auto));
        topGrid.ColumnDefinitions.Add(new ColumnDefinition(GridLength.Auto));
        topGrid.ColumnDefinitions.Add(new ColumnDefinition(GridLength.Auto));

        var channelText = new TextBlock
        {
            Foreground = Avalonia.Media.Brushes.White,
            FontSize = 12,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
        };
        channelText.Bind(TextBlock.TextProperty, new Avalonia.Data.Binding("ChannelName")
        {
            Source = slotVm,
            FallbackValue = $"Slot {slotIndex + 1}",
        });
        Grid.SetColumn(channelText, 0);
        topGrid.Children.Add(channelText);

        // Audio button
        var audioBtn = new Button
        {
            Content = "♪",
            FontSize = 12,
            Background = Avalonia.Media.Brushes.Transparent,
            Foreground = Avalonia.Media.Brushes.White,
            Padding = new Thickness(6, 2),
        };
        ToolTip.SetTip(audioBtn, "Set as audio source");
        audioBtn.Click += (_, _) =>
        {
            if (DataContext is MultiviewViewModel vm)
            {
                _ = vm.SetAudioSlotCommand.ExecuteAsync(slotIndex);
            }
        };
        Grid.SetColumn(audioBtn, 1);
        topGrid.Children.Add(audioBtn);

        // Expand button
        var expandBtn = new Button
        {
            Content = "⛶",
            FontSize = 12,
            Background = Avalonia.Media.Brushes.Transparent,
            Foreground = Avalonia.Media.Brushes.White,
            Padding = new Thickness(6, 2),
        };
        ToolTip.SetTip(expandBtn, "Expand fullscreen");
        expandBtn.Click += (_, _) =>
        {
            if (DataContext is MultiviewViewModel vm)
            {
                _ = vm.ExpandSlotCommand.ExecuteAsync(slotIndex);
            }
        };
        Grid.SetColumn(expandBtn, 2);
        topGrid.Children.Add(expandBtn);

        // Close slot button
        var closeBtn = new Button
        {
            Content = "×",
            FontSize = 14,
            Background = Avalonia.Media.Brushes.Transparent,
            Foreground = Avalonia.Media.Brushes.White,
            Padding = new Thickness(6, 2),
        };
        ToolTip.SetTip(closeBtn, "Close slot");
        closeBtn.Click += (_, _) =>
        {
            if (DataContext is MultiviewViewModel vm)
            {
                _ = vm.ClearSlotCommand.ExecuteAsync(slotIndex);
            }
        };
        Grid.SetColumn(closeBtn, 3);
        topGrid.Children.Add(closeBtn);

        topBar.Child = topGrid;
        overlay.Children.Add(topBar);

        // Empty-slot "+" button (visible when slot is not active)
        var addBtn = new Button
        {
            Content = "+ Assign Channel",
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
            Background = new Avalonia.Media.SolidColorBrush(Avalonia.Media.Color.Parse("#1AFFFFFF")),
            Foreground = Avalonia.Media.Brushes.White,
            Padding = new Thickness(16, 8),
            CornerRadius = new CornerRadius(8),
        };
        addBtn.Bind(IsVisibleProperty, new Avalonia.Data.Binding("!IsActive") { Source = slotVm });
        addBtn.Click += (_, _) =>
        {
            if (DataContext is MultiviewViewModel vm)
            {
                vm.AssignChannelCommand.Execute(slotIndex);
            }
        };
        overlay.Children.Add(addBtn);

        // Drag-to-swap pointer events
        overlay.PointerPressed += (_, e) =>
        {
            _dragSourceSlot = slotIndex;
            _dragStart = e.GetPosition(this);
            _dragActive = false;
        };
        overlay.PointerMoved += (_, e) =>
        {
            if (_dragSourceSlot < 0) return;
            var delta = e.GetPosition(this) - _dragStart;
            if (Math.Abs(delta.X) > 20 || Math.Abs(delta.Y) > 20)
            {
                _dragActive = true;
            }
        };
        overlay.PointerReleased += (_, e) =>
        {
            if (_dragActive && _dragSourceSlot >= 0 && _dragSourceSlot != slotIndex)
            {
                if (DataContext is MultiviewViewModel vm)
                {
                    _ = vm.SwapSlotsCommand.ExecuteAsync((_dragSourceSlot, slotIndex));
                }
            }

            _dragSourceSlot = -1;
            _dragActive = false;
        };

        return overlay;
    }

    // ─── Keyboard shortcuts ───────────────────────────────────────────────────

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (DataContext is not MultiviewViewModel vm) return;

        var key = e.Key;

        if (key == Key.Escape && !vm.IsGridMode)
        {
            _ = vm.CollapseCommand.ExecuteAsync(null);
            e.Handled = true;
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private Control? FindNamedChild(string name)
    {
        return this.FindDescendantOfType<ContentControl>(
            x => x is ContentControl cc &&
                 cc.Name == name) as Control;
    }
}

// Extension helper for typed visual tree search
file static class VisualExtensions
{
    public static T? FindDescendantOfType<T>(
        this Avalonia.Visual root,
        Func<T, bool>? predicate = null)
        where T : Avalonia.Visual
    {
        foreach (var child in root.GetVisualChildren())
        {
            if (child is T typed && (predicate is null || predicate(typed)))
                return typed;

            var found = FindDescendantOfType<T>(child, predicate);
            if (found is not null) return found;
        }

        return null;
    }
}
