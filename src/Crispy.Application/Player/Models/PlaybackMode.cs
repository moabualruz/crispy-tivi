namespace Crispy.Application.Player.Models;

/// <summary>
/// Describes the current playback mode — distinguishes live TV, timeshift, catch-up, VOD, and radio.
/// </summary>
public enum PlaybackMode
{
    /// <summary>Live TV stream playing at the live edge.</summary>
    Live,

    /// <summary>Live channel paused or rewound into the timeshift ring buffer.</summary>
    Timeshifted,

    /// <summary>Catch-up / restart TV — playing a past broadcast from an archive URL.</summary>
    Catchup,

    /// <summary>Video-on-demand content (movie or series episode).</summary>
    Vod,

    /// <summary>Audio-only radio stream.</summary>
    Radio,
}
