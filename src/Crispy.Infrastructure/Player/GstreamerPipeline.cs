namespace Crispy.Infrastructure.Player;

/// <summary>
/// Builds GStreamer pipeline description strings for various IPTV streaming protocols.
/// Pipeline strings follow the gst-launch-1.0 syntax and are designed to be parsed
/// with Gst.Parse.Launch() when GStreamer runtime becomes available.
///
/// All pipelines terminate with an appsink outputting BGRA frames for
/// <see cref="Crispy.Application.Player.IVideoFrameReceiver"/> consumption,
/// plus autoaudiosink for audio output.
/// </summary>
public static class GstreamerPipeline
{
    /// <summary>
    /// Specifies which pipeline template to use for a given stream URL.
    /// </summary>
    public enum PipelineMode
    {
        /// <summary>Automatic detection from URL scheme/extension.</summary>
        Auto,

        /// <summary>Force UDP multicast pipeline (tsdemux).</summary>
        Udp,

        /// <summary>Force RTSP pipeline (rtspsrc).</summary>
        Rtsp,

        /// <summary>Force HLS pipeline (hlsdemux via uridecodebin).</summary>
        Hls,

        /// <summary>Force generic uridecodebin pipeline.</summary>
        Generic,
    }

    private const string VideoSinkCaps = "video/x-raw,format=BGRA";
    private const string AppSinkConfig = "appsink name=videosink emit-signals=true caps=" + VideoSinkCaps;
    private const string AudioSink = "autoaudiosink";

    /// <summary>
    /// Builds a GStreamer pipeline description string for the given URL and mode.
    /// When <paramref name="mode"/> is <see cref="PipelineMode.Auto"/>, the protocol
    /// is detected from the URL scheme and file extension.
    /// </summary>
    /// <param name="url">The stream URL to play.</param>
    /// <param name="mode">Pipeline mode override; defaults to Auto.</param>
    /// <returns>A GStreamer pipeline description string suitable for Gst.Parse.Launch().</returns>
    public static string BuildPipeline(string url, PipelineMode mode = PipelineMode.Auto)
    {
        if (mode == PipelineMode.Auto)
        {
            mode = DetectMode(url);
        }

        return mode switch
        {
            PipelineMode.Udp => BuildUdpPipeline(url),
            PipelineMode.Rtsp => BuildRtspPipeline(url),
            PipelineMode.Hls => BuildGenericPipeline(url), // HLS uses uridecodebin (handles hlsdemux internally)
            _ => BuildGenericPipeline(url),
        };
    }

    /// <summary>
    /// Detects the appropriate pipeline mode from the URL scheme and extension.
    /// </summary>
    internal static PipelineMode DetectMode(string url)
    {
        if (string.IsNullOrWhiteSpace(url))
            return PipelineMode.Generic;

        var lower = url.ToLowerInvariant();

        if (lower.StartsWith("udp://", StringComparison.Ordinal))
            return PipelineMode.Udp;

        if (lower.StartsWith("rtsp://", StringComparison.Ordinal) ||
            lower.StartsWith("rtsps://", StringComparison.Ordinal))
            return PipelineMode.Rtsp;

        if (lower.Contains(".m3u8", StringComparison.Ordinal) ||
            lower.Contains("/hls/", StringComparison.Ordinal))
            return PipelineMode.Hls;

        return PipelineMode.Generic;
    }

    /// <summary>
    /// Generic pipeline using uridecodebin — handles HTTP progressive, HLS, DASH, and most protocols.
    /// </summary>
    private static string BuildGenericPipeline(string url)
    {
        return $"uridecodebin uri={EscapeUri(url)} name=demux " +
               $"demux. ! queue ! videoconvert ! {VideoSinkCaps} ! {AppSinkConfig} " +
               $"demux. ! queue ! audioconvert ! {AudioSink}";
    }

    /// <summary>
    /// UDP multicast pipeline — MPEG-TS demux with H.264 parsing.
    /// </summary>
    private static string BuildUdpPipeline(string url)
    {
        return $"udpsrc uri={EscapeUri(url)} ! tsdemux name=demux " +
               $"demux. ! queue ! h264parse ! decodebin ! videoconvert ! {VideoSinkCaps} ! {AppSinkConfig} " +
               $"demux. ! queue ! audioconvert ! {AudioSink}";
    }

    /// <summary>
    /// RTSP pipeline using rtspsrc for proper RTSP session handling.
    /// </summary>
    private static string BuildRtspPipeline(string url)
    {
        return $"rtspsrc location={EscapeUri(url)} name=demux " +
               $"demux. ! queue ! decodebin ! videoconvert ! {VideoSinkCaps} ! {AppSinkConfig} " +
               $"demux. ! queue ! decodebin ! audioconvert ! {AudioSink}";
    }

    /// <summary>
    /// Escapes a URI for safe embedding in a GStreamer pipeline description string.
    /// GStreamer pipeline strings are space-delimited, so spaces in URIs must be percent-encoded.
    /// </summary>
    private static string EscapeUri(string url)
    {
        // GStreamer pipeline descriptions are space-separated, so we must ensure
        // the URI has no unescaped spaces. Most URIs are already valid, but
        // some IPTV providers include spaces in their URLs.
        return url.Replace(" ", "%20");
    }
}
