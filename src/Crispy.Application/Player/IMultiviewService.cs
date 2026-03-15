using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Contract for the multiview feature: simultaneously playing up to 4 streams
/// in a quad grid with per-slot audio routing and named layout persistence.
///
/// Satisfies PLR-29 (4-up grid), PLR-30 (audio routing), PLR-31 (saved layouts),
/// PLR-32 (expand/swap slots).
/// </summary>
public interface IMultiviewService
{
    /// <summary>Always returns exactly 4 slots (indices 0–3).</summary>
    IReadOnlyList<MultiviewSlot> Slots { get; }

    /// <summary>Emits whenever any slot state changes.</summary>
    IObservable<IReadOnlyList<MultiviewSlot>> SlotsChanged { get; }

    /// <summary>Assigns a playback request to the given slot and starts playback.</summary>
    Task AssignSlotAsync(int slotIndex, PlaybackRequest request);

    /// <summary>Stops playback in the given slot and marks it empty.</summary>
    Task ClearSlotAsync(int slotIndex);

    /// <summary>
    /// Routes audio output to the specified slot; all other active slots are muted.
    /// </summary>
    Task SetActiveAudioSlotAsync(int slotIndex);

    /// <summary>Expands the specified slot to fullscreen, hiding the grid.</summary>
    Task ExpandSlotAsync(int slotIndex);

    /// <summary>Returns to the 4-up grid from fullscreen expanded mode.</summary>
    Task CollapseToGridAsync();

    /// <summary>Persists the current slot assignments under the given name.</summary>
    Task SaveLayoutAsync(string name);

    /// <summary>Returns all saved layouts ordered by creation time descending.</summary>
    Task<IReadOnlyList<SavedLayout>> GetSavedLayoutsAsync();

    /// <summary>Loads a saved layout, assigning each stored slot from persisted data.</summary>
    Task LoadLayoutAsync(string layoutId);

    /// <summary>Swaps the stream assignments (and playing state) of two slots.</summary>
    Task SwapSlotsAsync(int slotA, int slotB);

    /// <summary>Returns the IPlayerService backing the given slot (for VideoView wiring).</summary>
    IPlayerService GetSlotPlayer(int slotIndex);
}
