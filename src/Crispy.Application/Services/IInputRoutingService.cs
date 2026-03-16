namespace Crispy.Application.Services;

/// <summary>
/// Describes the current high-level state of the application for routing decisions.
/// </summary>
public enum AppState
{
    /// <summary>No media loaded, nothing playing.</summary>
    Idle,

    /// <summary>User is browsing content (channel list, EPG, VOD, etc.), nothing playing.</summary>
    Browsing,

    /// <summary>Media is playing fullscreen; content UI is hidden.</summary>
    Watching,

    /// <summary>Media is playing in the background while the content UI is visible.</summary>
    BrowsingWhilePlaying,
}

/// <summary>
/// Result of a key-handling attempt.
/// </summary>
public enum KeyHandleResult
{
    /// <summary>The key was consumed by the routing service.</summary>
    Handled,

    /// <summary>The key was not recognised or not applicable in the current state.</summary>
    NotHandled,
}
