using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Threading;

using Crispy.Application.Player;

namespace Crispy.UI.Controls;

/// <summary>
/// Displays video frames received via IVideoFrameReceiver as a WriteableBitmap.
/// No NativeControlHost — zero airspace issues. Video composites naturally with all UI.
/// This is the WriteableBitmap fallback/initial implementation.
/// Phase B+ will add D3D11 GPU interop on Windows.
/// </summary>
public class GpuVideoSurface : Control, IVideoFrameReceiver
{
    private WriteableBitmap? _bitmap;
    private readonly object _bitmapLock = new();

    /// <inheritdoc />
    public void OnFormatChanged(uint width, uint height)
    {
        Dispatcher.UIThread.Post(() =>
        {
            lock (_bitmapLock)
            {
                _bitmap = new WriteableBitmap(
                    new PixelSize((int)width, (int)height),
                    new Vector(96, 96),
                    PixelFormat.Bgra8888,
                    AlphaFormat.Premul);
            }

            InvalidateVisual();
        });
    }

    /// <inheritdoc />
    public void OnFrame(IntPtr buffer, uint width, uint height, uint pitch)
    {
        WriteableBitmap? bmp;
        lock (_bitmapLock)
        {
            bmp = _bitmap;
        }

        if (bmp is null) return;

        using (var fb = bmp.Lock())
        {
            unsafe
            {
                var src = (byte*)buffer;
                var dst = (byte*)fb.Address;
                var copyPitch = Math.Min(pitch, (uint)fb.RowBytes);
                for (var y = 0; y < height; y++)
                {
                    Buffer.MemoryCopy(
                        src + y * pitch,
                        dst + y * fb.RowBytes,
                        fb.RowBytes,
                        copyPitch);
                }
            }
        }

        Dispatcher.UIThread.Post(InvalidateVisual, DispatcherPriority.Render);
    }

    /// <inheritdoc />
    public void OnClear()
    {
        lock (_bitmapLock)
        {
            _bitmap = null;
        }

        Dispatcher.UIThread.Post(InvalidateVisual);
    }

    /// <inheritdoc />
    public override void Render(DrawingContext context)
    {
        WriteableBitmap? bmp;
        lock (_bitmapLock)
        {
            bmp = _bitmap;
        }

        if (bmp is not null)
        {
            context.DrawImage(
                bmp,
                new Rect(0, 0, bmp.Size.Width, bmp.Size.Height),
                new Rect(Bounds.Size));
        }
        else
        {
            context.FillRectangle(Brushes.Black, new Rect(Bounds.Size));
        }
    }
}
