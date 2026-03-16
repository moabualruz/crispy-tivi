using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.UI.Controls;
using Crispy.UI.ViewModels;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "Unit")]
public class VodSeekBarTests
{
    [AvaloniaFact]
    public void VodSeekBar_RendersWithoutException_WhenShownInWindow()
    {
        var control = new VodSeekBar();
        var window = new Window { Content = control, Width = 800, Height = 60 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void Position_DefaultsToZero()
    {
        var sut = new VodSeekBar();

        sut.Position.Should().Be(TimeSpan.Zero);
    }

    [AvaloniaFact]
    public void Duration_DefaultsToZero()
    {
        var sut = new VodSeekBar();

        sut.Duration.Should().Be(TimeSpan.Zero);
    }

    [AvaloniaFact]
    public void Chapters_DefaultsToNull()
    {
        var sut = new VodSeekBar();

        sut.Chapters.Should().BeNull();
    }

    [AvaloniaFact]
    public void Position_CanBeSet()
    {
        var sut = new VodSeekBar
        {
            Duration = TimeSpan.FromMinutes(90),
        };

        sut.Position = TimeSpan.FromMinutes(30);

        sut.Position.Should().Be(TimeSpan.FromMinutes(30));
    }

    [AvaloniaFact]
    public void Duration_CanBeSet()
    {
        var sut = new VodSeekBar();

        sut.Duration = TimeSpan.FromHours(2);

        sut.Duration.Should().Be(TimeSpan.FromHours(2));
    }

    [AvaloniaFact]
    public void SeekRequested_IsNotRaisedOnConstruction()
    {
        var sut = new VodSeekBar();
        TimeSpan? raised = null;
        sut.SeekRequested += (_, t) => raised = t;

        raised.Should().BeNull();
    }

    [AvaloniaFact]
    public void VodSeekBar_RendersWithAllPropertiesSet_WithoutException()
    {
        var control = new VodSeekBar
        {
            Duration = TimeSpan.FromMinutes(120),
            Position = TimeSpan.FromMinutes(45),
            Chapters =
            [
                new ChapterMark(TimeSpan.Zero, "Intro"),
                new ChapterMark(TimeSpan.FromMinutes(5), "Chapter 1"),
            ],
        };
        var window = new Window { Content = control, Width = 800, Height = 60 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }
}
