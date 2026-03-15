namespace Crispy.Application.Player.Models;

/// <summary>
/// An immutable 10-band equalizer preset.
/// Band frequencies (index 0→9): 32 Hz, 64 Hz, 125 Hz, 250 Hz, 500 Hz,
/// 1 kHz, 2 kHz, 4 kHz, 8 kHz, 16 kHz.
/// Each value is in dB, range [-12, +12].
/// </summary>
/// <param name="Name">Human-readable preset name.</param>
/// <param name="Bands">10 dB gain values; one per frequency band.</param>
public sealed record EqualizerPreset(string Name, float[] Bands)
{
    // ── Built-in presets ──────────────────────────────────────────────────────

    /// <summary>All bands at 0 dB.</summary>
    public static readonly EqualizerPreset Flat = new(
        "Flat",
        [0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f]);

    /// <summary>Boosted low-end (sub-bass and bass).</summary>
    public static readonly EqualizerPreset BassBoost = new(
        "Bass Boost",
        [6f, 5f, 4f, 2f, 0f, 0f, 0f, 0f, 0f, 0f]);

    /// <summary>Boosted high-end (presence and brilliance).</summary>
    public static readonly EqualizerPreset TrebleBoost = new(
        "Treble Boost",
        [0f, 0f, 0f, 0f, 0f, 0f, 2f, 4f, 5f, 6f]);

    /// <summary>Classical music — slightly cut mids, gentle low roll-off.</summary>
    public static readonly EqualizerPreset Classical = new(
        "Classical",
        [0f, 0f, 0f, 0f, -2f, -2f, 0f, 2f, 3f, 3f]);

    /// <summary>Rock — scooped mids, boosted lows and highs.</summary>
    public static readonly EqualizerPreset Rock = new(
        "Rock",
        [4f, 3f, 0f, -2f, -3f, -1f, 1f, 3f, 4f, 4f]);

    /// <summary>Pop — boosted mids and slightly boosted highs.</summary>
    public static readonly EqualizerPreset Pop = new(
        "Pop",
        [-1f, 0f, 2f, 3f, 4f, 3f, 2f, 0f, -1f, -1f]);

    /// <summary>Jazz — warm lows, slight mid boost, airy highs.</summary>
    public static readonly EqualizerPreset Jazz = new(
        "Jazz",
        [3f, 2f, 1f, 0f, -1f, 0f, 1f, 2f, 3f, 3f]);

    /// <summary>Vocal — boosts the vocal presence range (1–4 kHz).</summary>
    public static readonly EqualizerPreset Vocal = new(
        "Vocal",
        [-2f, -1f, 0f, 1f, 3f, 4f, 3f, 1f, 0f, -1f]);

    /// <summary>All built-in presets in display order.</summary>
    public static readonly IReadOnlyList<EqualizerPreset> BuiltIn =
    [
        Flat, BassBoost, TrebleBoost, Classical, Rock, Pop, Jazz, Vocal,
    ];
}
