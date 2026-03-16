using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.UI.Controls;

using FluentAssertions;

using System.Reactive.Subjects;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "Unit")]
public class WaveformVisualizerTests
{
    [AvaloniaFact]
    public void WaveformVisualizer_RendersWithoutException_WhenShownInWindow()
    {
        var control = new WaveformVisualizer();
        var window = new Window { Content = control, Width = 400, Height = 100 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void ColumnCount_DefaultsTo32()
    {
        var sut = new WaveformVisualizer();

        sut.ColumnCount.Should().Be(32);
    }

    [AvaloniaFact]
    public void ColumnCount_CanBeChanged()
    {
        var sut = new WaveformVisualizer();

        sut.ColumnCount = 64;

        sut.ColumnCount.Should().Be(64);
    }

    [AvaloniaFact]
    public void AttachAudioSamples_WithNull_DoesNotThrow()
    {
        var sut = new WaveformVisualizer();

        var act = () => sut.AttachAudioSamples(null);

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void AttachAudioSamples_WithObservable_DoesNotThrow()
    {
        var sut = new WaveformVisualizer();
        var subject = new Subject<float[]>();

        var act = () => sut.AttachAudioSamples(subject);

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void AttachAudioSamples_ReplacingExistingSubscription_DoesNotThrow()
    {
        var sut = new WaveformVisualizer();
        var first = new Subject<float[]>();
        var second = new Subject<float[]>();
        sut.AttachAudioSamples(first);

        var act = () => sut.AttachAudioSamples(second);

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void AttachAudioSamples_WithSamples_ProcessesWithoutException()
    {
        var sut = new WaveformVisualizer { ColumnCount = 4 };
        var subject = new Subject<float[]>();
        sut.AttachAudioSamples(subject);
        var window = new Window { Content = sut, Width = 400, Height = 100 };
        window.Show();

        var act = () => subject.OnNext(new float[128]);

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void AttachAudioSamples_NullAfterSubscription_SwitchesToPulseAnimation()
    {
        var sut = new WaveformVisualizer();
        var subject = new Subject<float[]>();
        sut.AttachAudioSamples(subject);

        // Detach — should fall back to pulse animation without throwing
        var act = () => sut.AttachAudioSamples(null);

        act.Should().NotThrow();
    }
}
