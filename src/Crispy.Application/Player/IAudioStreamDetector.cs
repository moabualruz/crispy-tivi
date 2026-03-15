using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Multi-signal heuristic for classifying a stream as audio-only (radio).
/// Returns true if ANY of the following signals indicates audio-only:
/// <list type="bullet">
///   <item><description>M3U attributes contain <c>radio="true"</c></description></item>
///   <item><description>MIME type starts with <c>audio/</c></description></item>
///   <item><description>The resolved track list contains zero video tracks</description></item>
///   <item><description>Group-title contains the word "radio" (case-insensitive)</description></item>
/// </list>
/// </summary>
public interface IAudioStreamDetector
{
    /// <summary>
    /// Determines whether the stream should be treated as audio-only.
    /// </summary>
    /// <param name="m3uAttributes">
    ///   Raw attribute string from the M3U <c>#EXTINF</c> line (may be null for non-M3U sources).
    /// </param>
    /// <param name="mimeType">
    ///   MIME type reported by the server or derived from the file extension (may be null).
    /// </param>
    /// <param name="tracks">
    ///   Track list after the player has opened the media; pass an empty list before tracks are known.
    /// </param>
    /// <param name="groupTitle">
    ///   M3U <c>group-title</c> attribute (may be null).
    /// </param>
    /// <returns>True when at least one signal classifies the stream as audio-only.</returns>
    bool IsAudioOnly(
        string? m3uAttributes,
        string? mimeType,
        IReadOnlyList<TrackInfo> tracks,
        string? groupTitle);
}
