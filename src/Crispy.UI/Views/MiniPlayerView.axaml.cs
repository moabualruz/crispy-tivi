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
    private bool _isDragging;

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        _dragStart = e.GetPosition(Parent as Visual ?? this);
        _originPosition = new Point(Margin.Left, Margin.Top);
        _isDragging = false;
        e.Pointer.Capture(this);
    }

    protected override void OnPointerMoved(PointerEventArgs e)
    {
        base.OnPointerMoved(e);
        if (e.Pointer.Captured != this) return;

        var pos = e.GetPosition(Parent as Visual ?? this);
        var delta = pos - _dragStart;

        if (Math.Abs(delta.X) > 4 || Math.Abs(delta.Y) > 4)
            _isDragging = true;

        if (_isDragging)
            Margin = new Avalonia.Thickness(_originPosition.X + delta.X, _originPosition.Y + delta.Y, 0, 0);
    }

    protected override void OnPointerReleased(PointerReleasedEventArgs e)
    {
        base.OnPointerReleased(e);
        e.Pointer.Capture(null);
        _isDragging = false;
    }

    private void OnVideoAreaTapped(object? sender, TappedEventArgs e)
    {
        if (DataContext is MiniPlayerViewModel vm)
            vm.ExpandCommand.Execute(null);
    }
}
