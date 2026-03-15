using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Threading;

using Crispy.Application.Player;

namespace Crispy.UI.Controls;

/// <summary>
/// Audio-reactive waveform visualizer for radio mode.
/// Subscribes to IObservable{float[]} AudioSamples from PlayerViewModel.
/// Computes per-column RMS and draws vertical bars using DrawingContext.
/// Falls back to a static pulsing animation when no AudioSamples are available.
/// </summary>
public partial class WaveformVisualizer : UserControl
{
    private IDisposable? _samplesSubscription;
    private float[] _currentBars = [];
    private DispatcherTimer? _pulseTimer;
    private double _pulsePhase;

    // ─── Columns property ───────────────────────────────────────────────────

    public static readonly StyledProperty<int> ColumnCountProperty =
        AvaloniaProperty.Register<WaveformVisualizer, int>(nameof(ColumnCount), defaultValue: 32);

    public int ColumnCount
    {
        get => GetValue(ColumnCountProperty);
        set => SetValue(ColumnCountProperty, value);
    }

    // ─────────────────────────────────────────────────────────────────────────

    public WaveformVisualizer()
    {
        InitializeComponent();
    }

    /// <summary>
    /// Subscribes to the given audio sample observable.
    /// Pass null to detach and fall back to the pulse animation.
    /// </summary>
    public void AttachAudioSamples(IObservable<float[]>? audioSamples)
    {
        _samplesSubscription?.Dispose();
        _pulseTimer?.Stop();

        if (audioSamples is null)
        {
            StartPulseAnimation();
            return;
        }

        _samplesSubscription = audioSamples.Subscribe(OnSamples);
    }

    private void OnSamples(float[] samples)
    {
        var cols = ColumnCount;
        if (cols <= 0 || samples.Length == 0) return;

        var bars = new float[cols];
        var samplesPerCol = samples.Length / cols;
        if (samplesPerCol == 0) return;

        for (int c = 0; c < cols; c++)
        {
            var offset = c * samplesPerCol;
            var sumSq = 0f;
            for (int i = offset; i < offset + samplesPerCol; i++)
                sumSq += samples[i] * samples[i];
            bars[c] = MathF.Sqrt(sumSq / samplesPerCol);
        }

        _currentBars = bars;
        Dispatcher.UIThread.Post(InvalidateVisual, DispatcherPriority.Render);
    }

    private void StartPulseAnimation()
    {
        _pulseTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(50) };
        _pulseTimer.Tick += (_, _) =>
        {
            _pulsePhase += 0.15;
            var cols = ColumnCount;
            var bars = new float[cols];
            for (int i = 0; i < cols; i++)
                bars[i] = (float)(0.3 + 0.3 * Math.Sin(_pulsePhase + i * 0.4));
            _currentBars = bars;
            InvalidateVisual();
        };
        _pulseTimer.Start();
    }

    // ─── Rendering ───────────────────────────────────────────────────────────

    public override void Render(DrawingContext context)
    {
        base.Render(context);

        var w = Bounds.Width;
        var h = Bounds.Height;
        if (w <= 0 || h <= 0) return;

        var bars = _currentBars;
        if (bars.Length == 0) return;

        var barWidth = w / bars.Length;
        var gap = barWidth * 0.2;
        var barW = barWidth - gap;

        // Use accent color — semi-transparent white as fallback
        IBrush barBrush = new SolidColorBrush(Color.FromArgb(200, 229, 57, 53));

        for (int i = 0; i < bars.Length; i++)
        {
            var amplitude = Math.Clamp(bars[i], 0.02f, 1f);
            var barH = amplitude * h * 0.8;
            var x = i * barWidth + gap / 2;
            var y = (h - barH) / 2;
            context.FillRectangle(barBrush, new Rect(x, y, barW, barH), 2);
        }
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        _samplesSubscription?.Dispose();
        _pulseTimer?.Stop();
    }
}
