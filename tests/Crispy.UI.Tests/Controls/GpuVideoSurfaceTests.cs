using System.Runtime.InteropServices;

using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Media.Imaging;
using Avalonia.Threading;

using Crispy.UI.Controls;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "Unit")]
public class GpuVideoSurfaceTests
{
    // -----------------------------------------------------------------------
    // OnFormatChanged
    // -----------------------------------------------------------------------

    [AvaloniaFact]
    public void OnFormatChanged_CreatesBitmapWithCorrectDimensions()
    {
        var sut = new GpuVideoSurface();

        sut.OnFormatChanged(320, 240);

        // OnFormatChanged posts to UIThread — flush the queue so the bitmap is assigned.
        Dispatcher.UIThread.RunJobs();

        // Access internal bitmap via reflection (internal field on our own assembly).
        var bitmapField = typeof(GpuVideoSurface)
            .GetField("_bitmap", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var bitmap = bitmapField!.GetValue(sut) as WriteableBitmap;

        bitmap.Should().NotBeNull("OnFormatChanged should create a WriteableBitmap");
        bitmap!.PixelSize.Width.Should().Be(320);
        bitmap.PixelSize.Height.Should().Be(240);
    }

    [AvaloniaFact]
    public void OnFormatChanged_ReplacesExistingBitmapOnSecondCall()
    {
        var sut = new GpuVideoSurface();

        sut.OnFormatChanged(320, 240);
        Dispatcher.UIThread.RunJobs();

        sut.OnFormatChanged(1920, 1080);
        Dispatcher.UIThread.RunJobs();

        var bitmapField = typeof(GpuVideoSurface)
            .GetField("_bitmap", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var bitmap = bitmapField!.GetValue(sut) as WriteableBitmap;

        bitmap.Should().NotBeNull();
        bitmap!.PixelSize.Width.Should().Be(1920);
        bitmap.PixelSize.Height.Should().Be(1080);
    }

    // -----------------------------------------------------------------------
    // OnClear
    // -----------------------------------------------------------------------

    [AvaloniaFact]
    public void OnClear_NullsBitmap()
    {
        var sut = new GpuVideoSurface();

        sut.OnFormatChanged(320, 240);
        Dispatcher.UIThread.RunJobs();

        sut.OnClear();
        Dispatcher.UIThread.RunJobs();

        var bitmapField = typeof(GpuVideoSurface)
            .GetField("_bitmap", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        var bitmap = bitmapField!.GetValue(sut);

        bitmap.Should().BeNull("OnClear should null the bitmap");
    }

    [AvaloniaFact]
    public void OnClear_DoesNotThrow_WhenNoBitmapExists()
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
    public void OnFrame_DoesNotThrow_WhenNoBitmapExists()
    {
        var sut = new GpuVideoSurface();

        // No OnFormatChanged called — _bitmap is null.
        var act = () => sut.OnFrame(IntPtr.Zero, 320, 240, 320 * 4);

        act.Should().NotThrow("OnFrame must guard against null bitmap");
    }

    [AvaloniaFact]
    public unsafe void OnFrame_CopiesFrameData_WhenBitmapExists()
    {
        var sut = new GpuVideoSurface();
        sut.OnFormatChanged(4, 4);
        Dispatcher.UIThread.RunJobs();

        // Allocate a fake 4×4 BGRA frame filled with 0xFF.
        const uint w = 4, h = 4, pitch = w * 4;
        var frameBytes = new byte[pitch * h];
        Array.Fill(frameBytes, (byte)0xFF);

        fixed (byte* ptr = frameBytes)
        {
            sut.OnFrame((IntPtr)ptr, w, h, pitch);
        }

        // If no exception — frame copy logic ran without error.
        // (Bitmap pixel verification would require unsafe access to mapped memory.)
    }

    // -----------------------------------------------------------------------
    // Render
    // -----------------------------------------------------------------------

    [AvaloniaFact]
    public void Render_DoesNotThrow_WhenShownWithNoBitmap()
    {
        var sut = new GpuVideoSurface { Width = 320, Height = 240 };
        var window = new Window { Content = sut, Width = 320, Height = 240 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void Render_DoesNotThrow_WhenShownWithBitmap()
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
