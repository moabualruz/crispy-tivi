namespace Crispy.Domain.Enums;

/// <summary>
/// Streaming protocol / container format for a stream endpoint.
/// </summary>
public enum StreamFormat
{
    /// <summary>Format could not be determined.</summary>
    Unknown = 0,

    /// <summary>HTTP Live Streaming (HLS / m3u8).</summary>
    HLS = 1,

    /// <summary>MPEG Transport Stream over HTTP.</summary>
    MpegTs = 2,

    /// <summary>MPEG-DASH (Dynamic Adaptive Streaming over HTTP).</summary>
    Dash = 3,

    /// <summary>Real-Time Messaging Protocol.</summary>
    Rtmp = 4,

    /// <summary>Real Time Streaming Protocol.</summary>
    Rtsp = 5,

    /// <summary>UDP multicast stream.</summary>
    Udp = 6,
}
