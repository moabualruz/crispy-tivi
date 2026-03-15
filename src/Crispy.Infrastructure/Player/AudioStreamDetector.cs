using Crispy.Application.Player;
using Crispy.Application.Player.Models;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// Multi-signal heuristic for classifying a stream as audio-only (radio).
/// Priority order: M3U radio attribute → MIME type → zero video tracks → group-title keyword.
/// </summary>
public sealed class AudioStreamDetector : IAudioStreamDetector
{
    /// <inheritdoc />
    public bool IsAudioOnly(
        string? m3uAttributes,
        string? mimeType,
        IReadOnlyList<TrackInfo> tracks,
        string? groupTitle)
    {
        // Signal 1: explicit radio="true" attribute in M3U #EXTINF line
        if (m3uAttributes != null &&
            m3uAttributes.Contains("radio=\"true\"", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // Signal 2: MIME type starts with "audio/"
        if (mimeType != null &&
            mimeType.StartsWith("audio/", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // Signal 3: resolved track list is non-empty and contains only audio tracks
        if (tracks.Count > 0 &&
            tracks.All(t => t.Kind == TrackKind.Audio))
        {
            return true;
        }

        // Signal 4: group-title contains the word "radio"
        if (groupTitle != null &&
            groupTitle.Contains("radio", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return false;
    }
}
