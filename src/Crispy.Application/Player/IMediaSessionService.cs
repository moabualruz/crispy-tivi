namespace Crispy.Application.Player;

/// <summary>
/// Updates the OS media session / Now Playing notification (lock-screen controls,
/// Android media notification, macOS Now Playing widget, etc.).
/// </summary>
public interface IMediaSessionService
{
    /// <summary>
    /// Updates the active media session with the current track metadata.
    /// </summary>
    /// <param name="title">Track / channel title displayed in the notification.</param>
    /// <param name="artist">Artist or channel name; null if not applicable.</param>
    /// <param name="artworkUrl">Remote URL for the lock-screen artwork image; null uses the app icon.</param>
    /// <param name="isPlaying">True when media is actively playing (controls play/pause icon).</param>
    Task UpdateNowPlayingAsync(string title, string? artist, string? artworkUrl, bool isPlaying);

    /// <summary>Removes the media session notification entirely (e.g. after Stop).</summary>
    Task ClearAsync();
}
