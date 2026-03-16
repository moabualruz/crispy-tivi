namespace Crispy.Application.Player;

/// <summary>
/// Receives decoded video frames from the player service for display.
/// </summary>
public interface IVideoFrameReceiver
{
    /// <summary>Called when a new frame is ready. Buffer is BGRA32, width×height pixels.</summary>
    void OnFrame(IntPtr buffer, uint width, uint height, uint pitch);

    /// <summary>Called when video format changes (resolution, etc).</summary>
    void OnFormatChanged(uint width, uint height);

    /// <summary>Called when playback stops — clear the surface.</summary>
    void OnClear();
}
