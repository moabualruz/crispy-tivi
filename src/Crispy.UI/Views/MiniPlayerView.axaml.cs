using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.VisualTree;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Views;

/// <summary>
/// Code-behind for the mini-player corner card.
/// Handles tap-to-expand and drag-to-reposition.
/// </summary>
public partial class MiniPlayerView : UserControl
{
    private Point _dragStart;
    private Point _originPosition;
    internal bool IsDragging { get; private set; }

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        var root = TopLevel.GetTopLevel(this) as Visual ?? (Parent as Visual ?? this);
        BeginDrag(e.GetPosition(root));
        e.Pointer.Capture(this);
    }

    protected override void OnPointerMoved(PointerEventArgs e)
    {
        base.OnPointerMoved(e);
        if (e.Pointer.Captured != this) return;

        var root = TopLevel.GetTopLevel(this) as Visual ?? (Parent as Visual ?? this);
        ApplyDragDelta(e.GetPosition(root));
    }

    protected override void OnPointerReleased(PointerReleasedEventArgs e)
    {
        base.OnPointerReleased(e);
        e.Pointer.Capture(null);
        EndDrag();
    }

    /// <summary>Starts a drag from the given position. Testable without pointer events.</summary>
    internal void BeginDrag(Point startPosition)
    {
        _dragStart = startPosition;
        _originPosition = new Point(Margin.Left, Margin.Top);
        IsDragging = false;
    }

    /// <summary>Applies drag delta from current position. Testable without pointer events.</summary>
    internal void ApplyDragDelta(Point currentPosition)
    {
        var delta = currentPosition - _dragStart;

        if (Math.Abs(delta.X) > 4 || Math.Abs(delta.Y) > 4)
            IsDragging = true;

        if (IsDragging)
            Margin = new Thickness(_originPosition.X + delta.X, _originPosition.Y + delta.Y, 0, 0);
    }

    /// <summary>Ends the drag gesture.</summary>
    internal void EndDrag()
    {
        IsDragging = false;
    }

    private void OnVideoAreaTapped(object? sender, TappedEventArgs e)
    {
        if (DataContext is MiniPlayerViewModel vm)
            vm.ExpandCommand.Execute(null);
    }
}
