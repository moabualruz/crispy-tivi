using Avalonia.Input;

using Crispy.Application.Services;

namespace Crispy.UI.Services;

/// <summary>
/// Routes keyboard and TV remote input to the correct app layer based on <see cref="AppState"/>.
/// Implements <see cref="IInputRoutingService"/>.
///
/// Routing rules:
/// - Media keys (Play/Pause/Stop/MediaNextTrack/MediaPreviousTrack) → player, always.
/// - Seek keys (OemOpenBrackets / OemCloseBrackets or Left/Right with Shift) → player, always.
/// - Escape: Watching → show content (BrowsingWhilePlaying); Browsing → navigate back.
/// - F key → toggle fullscreen (hide/show ContentLayer).
/// - Arrow / Enter / Back keys → OSD when Watching; ContentLayer when Browsing or BrowsingWhilePlaying.
/// </summary>
public class InputRoutingService : IInputRoutingService  // UI-layer interface (Crispy.UI.Services)
{
    // ── Media keys that always go to the player ──────────────────────────────

    private static readonly HashSet<Key> MediaKeys =
    [
        Key.MediaPlayPause,
        Key.MediaStop,
        Key.MediaNextTrack,
        Key.MediaPreviousTrack,
        Key.Play,
        Key.Pause,
        Key.Space,          // universal play/pause
    ];

    // ── Navigation keys (arrow cluster + confirm/back) ───────────────────────

    private static readonly HashSet<Key> NavigationKeys =
    [
        Key.Up,
        Key.Down,
        Key.Left,
        Key.Right,
        Key.Enter,
        Key.Back,
        Key.BrowserBack,
    ];

    /// <inheritdoc/>
    public KeyHandleResult HandleKey(Key key, KeyModifiers modifiers, AppState currentState)
    {
        // ── 1. Media keys → player regardless of state ───────────────────────
        if (MediaKeys.Contains(key))
            return KeyHandleResult.Handled; // caller dispatches to PlayerViewModel

        // ── 2. Seek: Left/Right + Shift modifier → player ────────────────────
        if (modifiers.HasFlag(KeyModifiers.Shift) &&
            (key is Key.Left or Key.Right))
            return KeyHandleResult.Handled;

        // ── 3. Escape handling ───────────────────────────────────────────────
        if (key == Key.Escape)
        {
            return currentState switch
            {
                AppState.Watching => KeyHandleResult.Handled, // show content layer
                AppState.Browsing => KeyHandleResult.Handled, // go back in nav stack
                AppState.BrowsingWhilePlaying => KeyHandleResult.Handled, // close content overlay
                _ => KeyHandleResult.NotHandled,
            };
        }

        // ── 4. F key → toggle fullscreen ─────────────────────────────────────
        if (key == Key.F && modifiers == KeyModifiers.None)
            return KeyHandleResult.Handled;

        // ── 5. Navigation keys ───────────────────────────────────────────────
        if (NavigationKeys.Contains(key))
        {
            return currentState switch
            {
                // Arrow/Enter when watching → OSD layer
                AppState.Watching => KeyHandleResult.Handled,

                // Arrow/Enter when browsing (with or without playback) → content layer
                AppState.Browsing or AppState.BrowsingWhilePlaying => KeyHandleResult.Handled,

                _ => KeyHandleResult.NotHandled,
            };
        }

        return KeyHandleResult.NotHandled;
    }
}
