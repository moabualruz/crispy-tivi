using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Controls;

/// <summary>
/// Custom seek bar for VOD content.
/// Renders a standard progress bar with chapter tick marks and a draggable thumb.
/// </summary>
public partial class VodSeekBar : UserControl
{
    // ─── Styled Properties ───────────────────────────────────────────────────

    public static readonly StyledProperty<TimeSpan> PositionProperty =
        AvaloniaProperty.Register<VodSeekBar, TimeSpan>(nameof(Position));

    public static readonly StyledProperty<TimeSpan> DurationProperty =
        AvaloniaProperty.Register<VodSeekBar, TimeSpan>(nameof(Duration));

    public static readonly StyledProperty<IReadOnlyList<ChapterMark>?> ChaptersProperty =
        AvaloniaProperty.Register<VodSeekBar, IReadOnlyList<ChapterMark>?>(nameof(Chapters));

    public TimeSpan Position
    {
        get => GetValue(PositionProperty);
        set => SetValue(PositionProperty, value);
    }

    public TimeSpan Duration
    {
        get => GetValue(DurationProperty);
        set => SetValue(DurationProperty, value);
    }

    public IReadOnlyList<ChapterMark>? Chapters
    {
        get => GetValue(ChaptersProperty);
        set => SetValue(ChaptersProperty, value);
    }

    // ─── Seek event ──────────────────────────────────────────────────────────

    public event EventHandler<TimeSpan>? SeekRequested;

    // ─── Drag state ──────────────────────────────────────────────────────────

    private bool _isDragging;

    // ─────────────────────────────────────────────────────────────────────────

    public VodSeekBar()
    {
        InitializeComponent();

        PositionProperty.Changed.AddClassHandler<VodSeekBar>((o, _) => o.InvalidateVisual());
        DurationProperty.Changed.AddClassHandler<VodSeekBar>((o, _) => o.InvalidateVisual());
        ChaptersProperty.Changed.AddClassHandler<VodSeekBar>((o, _) => o.InvalidateVisual());
    }

    // ─── Rendering ───────────────────────────────────────────────────────────

    public override void Render(DrawingContext context)
    {
        base.Render(context);

        var w = Bounds.Width;
        const double trackY = 20;
        const double trackH = 4;
        const double thumbR = 7;

        if (w <= 0 || Duration == TimeSpan.Zero) return;

        double ToX(TimeSpan t) => t.TotalSeconds / Duration.TotalSeconds * w;

        // Background track
        context.FillRectangle(
            new SolidColorBrush(Color.FromArgb(80, 255, 255, 255)),
            new Rect(0, trackY, w, trackH),
            2);

        // Played range
        var px = ToX(Position);
        if (px > 0)
            context.FillRectangle(
                new SolidColorBrush(Color.FromArgb(220, 229, 57, 53)),
                new Rect(0, trackY, Math.Min(px, w), trackH),
                2);

        // Chapter ticks
        if (Chapters is { } chapters)
        {
            var tickBrush = new SolidColorBrush(Color.FromArgb(200, 255, 255, 255));
            foreach (var ch in chapters)
            {
                var tx = ToX(ch.Position);
                if (tx > 2 && tx < w - 2)
                    context.FillRectangle(tickBrush, new Rect(tx - 1, trackY - 3, 2, trackH + 6));
            }
        }

        // Thumb
        var thumbX = Math.Clamp(px, thumbR, w - thumbR);
        context.DrawEllipse(
            Brushes.White,
            null,
            new Point(thumbX, trackY + trackH / 2),
            thumbR, thumbR);
    }

    // ─── Pointer events ───────────────────────────────────────────────────────

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        _isDragging = true;
        e.Pointer.Capture(this);
        UpdatePositionFromPointer(e.GetPosition(this).X);
    }

    protected override void OnPointerMoved(PointerEventArgs e)
    {
        base.OnPointerMoved(e);
        if (!_isDragging) return;
        UpdatePositionFromPointer(e.GetPosition(this).X);
    }

    protected override void OnPointerReleased(PointerReleasedEventArgs e)
    {
        base.OnPointerReleased(e);
        if (!_isDragging) return;
        _isDragging = false;
        e.Pointer.Capture(null);
        SeekRequested?.Invoke(this, Position);
    }

    private void UpdatePositionFromPointer(double x)
    {
        if (Duration == TimeSpan.Zero) return;
        var ratio = Math.Clamp(x / Bounds.Width, 0, 1);
        Position = TimeSpan.FromSeconds(ratio * Duration.TotalSeconds);
        InvalidateVisual();
    }
}
