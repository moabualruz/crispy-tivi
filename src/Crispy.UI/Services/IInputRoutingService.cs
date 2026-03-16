using Avalonia.Input;

using Crispy.Application.Services;

namespace Crispy.UI.Services;

/// <summary>
/// Routes keyboard and TV remote input to the appropriate layer based on current app state.
/// </summary>
public interface IInputRoutingService
{
    /// <summary>
    /// Handles a key press and returns whether it was consumed.
    /// </summary>
    KeyHandleResult HandleKey(Key key, KeyModifiers modifiers, AppState currentState);
}
