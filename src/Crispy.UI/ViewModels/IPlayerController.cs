using Crispy.Application.Player.Models;

namespace Crispy.UI.ViewModels;

/// <summary>
/// Abstraction over the singleton PlayerViewModel used by content ViewModels
/// to trigger playback without coupling to the concrete type.
/// </summary>
public interface IPlayerController
{
    /// <summary>
    /// Starts playback for the given request.
    /// </summary>
    Task PlayAsync(PlaybackRequest request);
}
