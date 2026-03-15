namespace Crispy.Application.Player.Models;

/// <summary>
/// Immutable snapshot of one slot in the multiview grid.
/// </summary>
/// <param name="SlotIndex">0-based index in the 2×2 quad grid (0=TL, 1=TR, 2=BL, 3=BR).</param>
/// <param name="Request">The playback request loaded into this slot; null = empty slot.</param>
/// <param name="IsActive">True when a stream has been assigned and is playing.</param>
/// <param name="IsAudioActive">True when this slot's audio is routed to the output; others are muted.</param>
/// <param name="IsExpanded">True when this slot is displayed fullscreen instead of grid mode.</param>
public sealed record MultiviewSlot(
    int SlotIndex,
    PlaybackRequest? Request,
    bool IsActive,
    bool IsAudioActive,
    bool IsExpanded);
