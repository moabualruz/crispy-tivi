using System.Runtime.InteropServices;

using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Platform;
using Avalonia.Rendering.SceneGraph;
using Avalonia.Skia;
using Avalonia.Threading;

using Crispy.Application.Player;

using SkiaSharp;

namespace Crispy.UI.Controls;

/// <summary>
/// High-performance video surface using SkiaSharp GPU-accelerated rendering.
/// Receives raw BGRA frames from GStreamer appsink via IVideoFrameReceiver,
/// uploads to SKImage, and renders via ICustomDrawOperation on Skia's GPU canvas.
/// No WriteableBitmap, no NativeControlHost — zero airspace, GPU compositing.
/// </summary>
public class GpuVideoSurface : Control, IVideoFrameReceiver
{
    // Double-buffered SKImage: decode thread writes back, UI thread reads front
    private SKImage? _frontImage;
    private SKImage? _backImage;
    private volatile bool _frameReady;
    private volatile bool _invalidatePending;
    private uint _currentWidth, _currentHeight;
    private readonly object _swapLock = new();

    /// <inheritdoc />
    public void OnFormatChanged(uint width, uint height)
    {
        _currentWidth = width;
        _currentHeight = height;
        _frameReady = false;
        Dispatcher.UIThread.Post(InvalidateVisual);
    }

    /// <inheritdoc />
    public void OnFrame(IntPtr buffer, uint width, uint height, uint pitch)
    {
        if (width == 0 || height == 0 || buffer == IntPtr.Zero) return;
        if (width != _currentWidth || height != _currentHeight) return;

        // Create SKImage from the raw pixel data — Skia copies into its managed memory
        // and handles GPU upload during rendering. This is faster than WriteableBitmap
        // because it bypasses Avalonia's bitmap abstraction layer entirely.
        var info = new SKImageInfo((int)width, (int)height, SKColorType.Bgra8888, SKAlphaType.Premul);
        var image = SKImage.FromPixelCopy(info, buffer, (int)pitch);

        if (image is null) return;

        lock (_swapLock)
        {
            _backImage?.Dispose();
            _backImage = image;
        }

        _frameReady = true;

        // Coalesce: one InvalidateVisual per render cycle
        if (!_invalidatePending)
        {
            _invalidatePending = true;
            Dispatcher.UIThread.Post(() =>
            {
                _invalidatePending = false;
                if (_frameReady)
                {
                    lock (_swapLock)
                    {
                        _frontImage?.Dispose();
                        _frontImage = _backImage;
                        _backImage = null;
                        _frameReady = false;
                    }
                    InvalidateVisual();
                }
            }, DispatcherPriority.Render);
        }
    }

    /// <inheritdoc />
    public void OnClear()
    {
        lock (_swapLock)
        {
            _frontImage?.Dispose();
            _frontImage = null;
            _backImage?.Dispose();
            _backImage = null;
        }
        _frameReady = false;
        Dispatcher.UIThread.Post(InvalidateVisual);
    }

    /// <inheritdoc />
    public override void Render(DrawingContext context)
    {
        SKImage? snapshot;
        lock (_swapLock)
        {
            // Take a non-owning snapshot — safe to use after lock release
            // because SKImage is immutable and refcounted internally.
            snapshot = _frontImage;
        }

        if (snapshot is not null)
        {
            var op = new VideoDrawOperation(new Rect(Bounds.Size), snapshot);
            context.Custom(op);
        }
        else
        {
            context.FillRectangle(Brushes.Black, new Rect(Bounds.Size));
        }
    }

    /// <summary>
    /// Custom draw operation that renders an SKImage directly on Skia's GPU canvas.
    /// Holds its own reference to prevent use-after-dispose during render.
    /// </summary>
    private sealed class VideoDrawOperation : ICustomDrawOperation
    {
        private readonly Rect _bounds;
        private SKImage? _image;

        public VideoDrawOperation(Rect bounds, SKImage image)
        {
            _bounds = bounds;
            // Defensive clone — ensures this image survives even if
            // GpuVideoSurface swaps/disposes the original during render.
            _image = image.Subset(new SKRectI(0, 0, image.Width, image.Height));
        }

        public Rect Bounds => _bounds;

        public void Dispose()
        {
            _image?.Dispose();
            _image = null;
        }

        public bool Equals(ICustomDrawOperation? other) => false;

        public bool HitTest(Point p) => _bounds.Contains(p);

        public void Render(ImmediateDrawingContext context)
        {
            if (_image is null) return;

            var leaseFeature = context.TryGetFeature<ISkiaSharpApiLeaseFeature>();
            if (leaseFeature is null) return;

            using var lease = leaseFeature.Lease();
            var canvas = lease.SkCanvas;

            var dest = new SKRect(0, 0, (float)_bounds.Width, (float)_bounds.Height);

            using var paint = new SKPaint
            {
                FilterQuality = SKFilterQuality.Medium,
                IsAntialias = false,
            };

            canvas.DrawImage(_image, dest, paint);
        }
    }
}
