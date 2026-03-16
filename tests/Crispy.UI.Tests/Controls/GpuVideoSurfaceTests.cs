using System.Runtime.InteropServices;

using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Threading;

using Crispy.UI.Controls;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "Unit")]
public class GpuVideoSurfaceTests
{
    private static object? GetField(GpuVideoSurface sut, string name) =>
        typeof(GpuVideoSurface)
            .GetField(name, System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
            ?.GetValue(sut);

    // -----------------------------------------------------------------------
    // OnFormatChanged
    // -----------------------------------------------------------------------

    [AvaloniaFact]
    public void OnFormatChanged_SetsCurrentDimensions()
    {
        var sut = new GpuVideoSurface();

        sut.OnFormatChanged(1920, 1080);

        var width = GetField(sut, "_currentWidth");
        var height = GetField(sut, "_currentHeight");

        width.Should().Be(1920u);
        height.Should().Be(1080u);
    }

    [AvaloniaFact]
    public void OnFormatChanged_ReplacesOnSecondCall()
    {
        var sut = new GpuVideoSurface();

        sut.OnFormatChanged(320, 240);
        sut.OnFormatChanged(1920, 1080);

        var width = GetField(sut, "_currentWidth");
        width.Should().Be(1920u);
    }

    // -----------------------------------------------------------------------
    // OnClear
    // -----------------------------------------------------------------------

    [AvaloniaFact]
    public void OnClear_NullsFrontAndBackImages()
    {
        var sut = new GpuVideoSurface();

        sut.OnFormatChanged(320, 240);
        Dispatcher.UIThread.RunJobs();

        sut.OnClear();
        Dispatcher.UIThread.RunJobs();

        GetField(sut, "_frontImage").Should().BeNull();
        GetField(sut, "_backImage").Should().BeNull();
    }

    [AvaloniaFact]
    public void OnClear_DoesNotThrow_WhenEmpty()
    {
        var sut = new GpuVideoSurface();

        var act = () =>
        {
            sut.OnClear();
            Dispatcher.UIThread.RunJobs();
        };

        act.Should().NotThrow();
    }

    // -----------------------------------------------------------------------
    // OnFrame
    // -----------------------------------------------------------------------

    [AvaloniaFact]
    public void OnFrame_DoesNotThrow_WhenNoFormatSet()
    {
        var sut = new GpuVideoSurface();

        var act = () => sut.OnFrame(IntPtr.Zero, 320, 240, 320 * 4);

        act.Should().NotThrow("OnFrame must guard against zero buffer");
    }

    [AvaloniaFact]
    public unsafe void OnFrame_CreatesBackImage_WhenFormatSet()
    {
        var sut = new GpuVideoSurface();
        sut.OnFormatChanged(4, 4);

        const uint w = 4, h = 4, pitch = w * 4;
        var frameBytes = new byte[pitch * h];
        Array.Fill(frameBytes, (byte)0xFF);

        fixed (byte* ptr = frameBytes)
        {
            sut.OnFrame((IntPtr)ptr, w, h, pitch);
        }

        // Back image should have been created
        var frameReady = GetField(sut, "_frameReady");
        frameReady.Should().Be(true, "OnFrame should signal a new frame is ready");
    }

    // -----------------------------------------------------------------------
    // Render
    // -----------------------------------------------------------------------

    [AvaloniaFact]
    public void Render_DoesNotThrow_WhenShownEmpty()
    {
        var sut = new GpuVideoSurface { Width = 320, Height = 240 };
        var window = new Window { Content = sut, Width = 320, Height = 240 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void Render_DoesNotThrow_WhenShownWithFrame()
    {
        var sut = new GpuVideoSurface { Width = 320, Height = 240 };
        sut.OnFormatChanged(320, 240);
        Dispatcher.UIThread.RunJobs();

        var window = new Window { Content = sut, Width = 320, Height = 240 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }
}
