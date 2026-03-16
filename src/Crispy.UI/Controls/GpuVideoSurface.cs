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
/// Uses double buffering and frame coalescing for smooth playback.
/// </summary>
public class GpuVideoSurface : Control, IVideoFrameReceiver
{
    private WriteableBitmap? _frontBuffer;  // displayed by Render
    private WriteableBitmap? _backBuffer;   // written by OnFrame
    private volatile bool _frameReady;      // signals a new frame is available
    private volatile bool _invalidatePending; // prevents redundant Dispatcher posts
    private uint _currentWidth, _currentHeight;

    /// <inheritdoc />
    public void OnFormatChanged(uint width, uint height)
    {
        _currentWidth = width;
        _currentHeight = height;

        var size = new PixelSize((int)width, (int)height);
        var dpi = new Vector(96, 96);

        // Create both buffers on UI thread
        Dispatcher.UIThread.Post(() =>
        {
            _backBuffer = new WriteableBitmap(size, dpi, PixelFormat.Bgra8888, AlphaFormat.Premul);
            _frontBuffer = new WriteableBitmap(size, dpi, PixelFormat.Bgra8888, AlphaFormat.Premul);
            _frameReady = false;
            InvalidateVisual();
        });
    }

    /// <inheritdoc />
    public void OnFrame(IntPtr buffer, uint width, uint height, uint pitch)
    {
        var bmp = _backBuffer;
        if (bmp is null || width != _currentWidth || height != _currentHeight)
            return;

        using (var fb = bmp.Lock())
        {
            unsafe
            {
                var src = (byte*)buffer;
                var dst = (byte*)fb.Address;
                var dstPitch = (uint)fb.RowBytes;

                if (pitch == dstPitch)
                {
                    // Fast path: single bulk copy when pitches match
                    Buffer.MemoryCopy(src, dst, dstPitch * height, pitch * height);
                }
                else
                {
                    // Slow path: row-by-row when pitches differ
                    var copyBytes = Math.Min(pitch, dstPitch);
                    for (var y = 0; y < height; y++)
                    {
                        Buffer.MemoryCopy(
                            src + y * pitch,
                            dst + y * dstPitch,
                            dstPitch, copyBytes);
                    }
                }
            }
        }

        _frameReady = true;

        // Coalesce: only post one InvalidateVisual per render cycle
        if (!_invalidatePending)
        {
            _invalidatePending = true;
            Dispatcher.UIThread.Post(() =>
            {
                _invalidatePending = false;
                if (_frameReady)
                {
                    // Swap buffers
                    (_frontBuffer, _backBuffer) = (_backBuffer, _frontBuffer);
                    _frameReady = false;
                    InvalidateVisual();
                }
            }, DispatcherPriority.Render);
        }
    }

    /// <inheritdoc />
    public void OnClear()
    {
        _frameReady = false;
        _frontBuffer = null;
        _backBuffer = null;

        Dispatcher.UIThread.Post(InvalidateVisual);
    }

    /// <inheritdoc />
    public override void Render(DrawingContext context)
    {
        var bmp = _frontBuffer;

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
