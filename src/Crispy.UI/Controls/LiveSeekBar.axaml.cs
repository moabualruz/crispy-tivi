using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Controls;

/// <summary>
/// Custom seek bar for live TV / timeshift.
/// Renders: dark background bar, lighter fill from BufferStart→BufferEnd,
/// primary fill 0→Position, live-edge indicator (red LIVE dot or grey offset),
/// programme boundary tick marks.
/// Thumb drag is constrained within the buffered range.
/// </summary>
public partial class LiveSeekBar : UserControl
{
    // ─── Styled Properties ───────────────────────────────────────────────────

    public static readonly StyledProperty<TimeSpan> BufferStartProperty =
        AvaloniaProperty.Register<LiveSeekBar, TimeSpan>(nameof(BufferStart));

    public static readonly StyledProperty<TimeSpan> BufferEndProperty =
        AvaloniaProperty.Register<LiveSeekBar, TimeSpan>(nameof(BufferEnd));

    public static readonly StyledProperty<TimeSpan> LiveEdgeProperty =
        AvaloniaProperty.Register<LiveSeekBar, TimeSpan>(nameof(LiveEdge));

    public static readonly StyledProperty<TimeSpan> PositionProperty =
        AvaloniaProperty.Register<LiveSeekBar, TimeSpan>(nameof(Position));

    public static readonly StyledProperty<IReadOnlyList<EpgProgrammeRef>?> ProgrammesProperty =
        AvaloniaProperty.Register<LiveSeekBar, IReadOnlyList<EpgProgrammeRef>?>(nameof(Programmes));

    public TimeSpan BufferStart
    {
        get => GetValue(BufferStartProperty);
        set => SetValue(BufferStartProperty, value);
    }

    public TimeSpan BufferEnd
    {
        get => GetValue(BufferEndProperty);
        set => SetValue(BufferEndProperty, value);
    }

    public TimeSpan LiveEdge
    {
        get => GetValue(LiveEdgeProperty);
        set => SetValue(LiveEdgeProperty, value);
    }

    public TimeSpan Position
    {
        get => GetValue(PositionProperty);
        set => SetValue(PositionProperty, value);
    }

    public IReadOnlyList<EpgProgrammeRef>? Programmes
    {
        get => GetValue(ProgrammesProperty);
        set => SetValue(ProgrammesProperty, value);
    }

    // ─── Seek event ──────────────────────────────────────────────────────────

    public event EventHandler<TimeSpan>? SeekRequested;

    // ─── Drag state ──────────────────────────────────────────────────────────

    private bool _isDragging;
    private double _dragStartX;

    // ─────────────────────────────────────────────────────────────────────────

    public LiveSeekBar()
    {
        InitializeComponent();

        // Invalidate on property changes
        BufferStartProperty.Changed.AddClassHandler<LiveSeekBar>((o, _) => o.InvalidateVisual());
        BufferEndProperty.Changed.AddClassHandler<LiveSeekBar>((o, _) => o.InvalidateVisual());
        LiveEdgeProperty.Changed.AddClassHandler<LiveSeekBar>((o, _) => o.InvalidateVisual());
        PositionProperty.Changed.AddClassHandler<LiveSeekBar>((o, _) => o.InvalidateVisual());
        ProgrammesProperty.Changed.AddClassHandler<LiveSeekBar>((o, _) => o.InvalidateVisual());
    }

    // ─── Rendering ───────────────────────────────────────────────────────────

    public override void Render(DrawingContext context)
    {
        base.Render(context);

        var w = Bounds.Width;
        const double trackY = 20;
        const double trackH = 6;
        const double thumbR = 8;

        if (w <= 0 || LiveEdge == TimeSpan.Zero) return;

        var totalSeconds = LiveEdge.TotalSeconds;

        double ToX(TimeSpan t) => t.TotalSeconds / totalSeconds * w;

        // Background track
        context.FillRectangle(
            new SolidColorBrush(Color.FromArgb(80, 255, 255, 255)),
            new Rect(0, trackY, w, trackH),
            3);

        // Buffered range (lighter fill)
        var bx = ToX(BufferStart);
        var bw = ToX(BufferEnd) - bx;
        if (bw > 0)
            context.FillRectangle(
                new SolidColorBrush(Color.FromArgb(120, 255, 255, 255)),
                new Rect(bx, trackY, bw, trackH),
                3);

        // Played range (primary fill — accent color)
        var px = ToX(Position);
        if (px > 0)
            context.FillRectangle(
                new SolidColorBrush(Color.FromArgb(220, 229, 57, 53)), // red-400
                new Rect(0, trackY, Math.Min(px, w), trackH),
                3);

        // Programme boundary ticks
        if (Programmes is { } progs)
        {
            var tickBrush = new SolidColorBrush(Color.FromArgb(160, 255, 255, 255));
            foreach (var prog in progs)
            {
                var tx = ToX(prog.StartTime - (DateTimeOffset.UtcNow - LiveEdge));
                if (tx > 2 && tx < w - 2)
                    context.FillRectangle(tickBrush, new Rect(tx - 1, trackY - 2, 2, trackH + 4));
            }
        }

        // Thumb
        var thumbX = Math.Clamp(px, thumbR, w - thumbR);
        context.DrawEllipse(
            Brushes.White,
            null,
            new Point(thumbX, trackY + trackH / 2),
            thumbR, thumbR);

        // Live-edge indicator
        var isAtLive = Math.Abs(Position.TotalSeconds - LiveEdge.TotalSeconds) < 2;
        var dotColor = isAtLive ? Color.FromRgb(229, 57, 53) : Color.FromRgb(150, 150, 150);
        context.DrawEllipse(
            new SolidColorBrush(dotColor),
            null,
            new Point(w - 6, trackY + trackH / 2),
            5, 5);
    }

    // ─── Pointer events (drag to seek) ───────────────────────────────────────

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        _isDragging = true;
        _dragStartX = e.GetPosition(this).X;
        e.Pointer.Capture(this);
    }

    protected override void OnPointerMoved(PointerEventArgs e)
    {
        base.OnPointerMoved(e);
        if (!_isDragging) return;

        var x = Math.Clamp(e.GetPosition(this).X, 0, Bounds.Width);
        if (LiveEdge == TimeSpan.Zero) return;

        var ratio = x / Bounds.Width;
        var seekTo = TimeSpan.FromSeconds(ratio * LiveEdge.TotalSeconds);

        // Constrain to buffered range
        seekTo = seekTo < BufferStart ? BufferStart : seekTo;
        seekTo = seekTo > BufferEnd ? BufferEnd : seekTo;

        Position = seekTo;
        InvalidateVisual();
    }

    protected override void OnPointerReleased(PointerReleasedEventArgs e)
    {
        base.OnPointerReleased(e);
        if (!_isDragging) return;
        _isDragging = false;
        e.Pointer.Capture(null);
        SeekRequested?.Invoke(this, Position);
    }
}
