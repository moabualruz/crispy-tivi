using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.UI.Controls;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "Unit")]
public class LiveSeekBarTests
{
    [AvaloniaFact]
    public void LiveSeekBar_RendersWithoutException_WhenShownInWindow()
    {
        var control = new LiveSeekBar();
        var window = new Window { Content = control, Width = 800, Height = 100 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void Position_DefaultsToZero()
    {
        var sut = new LiveSeekBar();

        sut.Position.Should().Be(TimeSpan.Zero);
    }

    [AvaloniaFact]
    public void BufferEnd_DefaultsToZero()
    {
        var sut = new LiveSeekBar();

        sut.BufferEnd.Should().Be(TimeSpan.Zero);
    }

    [AvaloniaFact]
    public void LiveEdge_DefaultsToZero()
    {
        var sut = new LiveSeekBar();

        sut.LiveEdge.Should().Be(TimeSpan.Zero);
    }

    [AvaloniaFact]
    public void Position_AcceptsAssignment_WhenWithinBuffer()
    {
        var sut = new LiveSeekBar
        {
            BufferStart = TimeSpan.Zero,
            BufferEnd = TimeSpan.FromMinutes(30),
            LiveEdge = TimeSpan.FromMinutes(30),
        };

        sut.Position = TimeSpan.FromMinutes(10);

        sut.Position.Should().Be(TimeSpan.FromMinutes(10));
    }

    [AvaloniaFact]
    public void Programmes_DefaultsToNull()
    {
        var sut = new LiveSeekBar();

        sut.Programmes.Should().BeNull();
    }

    [AvaloniaFact]
    public void SeekRequested_IsNotRaisedOnConstruction()
    {
        var sut = new LiveSeekBar();
        TimeSpan? raised = null;
        sut.SeekRequested += (_, t) => raised = t;

        raised.Should().BeNull();
    }

    [AvaloniaFact]
    public void LiveSeekBar_RendersWithAllPropertiesSet_WithoutException()
    {
        var control = new LiveSeekBar
        {
            BufferStart = TimeSpan.Zero,
            BufferEnd = TimeSpan.FromMinutes(60),
            LiveEdge = TimeSpan.FromMinutes(60),
            Position = TimeSpan.FromMinutes(20),
        };
        var window = new Window { Content = control, Width = 800, Height = 60 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }
}
