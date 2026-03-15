using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Contract for the 10-band graphic equalizer.
///
/// Band indices map to centre frequencies:
/// 0=32 Hz, 1=64 Hz, 2=125 Hz, 3=250 Hz, 4=500 Hz,
/// 5=1 kHz, 6=2 kHz, 7=4 kHz, 8=8 kHz, 9=16 kHz.
///
/// Satisfies PLR-33 (audio equalizer overlay).
/// </summary>
public interface IEqualizerService
{
    /// <summary>True when the equalizer is currently applied to the audio output.</summary>
    bool IsEnabled { get; }

    /// <summary>Current gain values in dB for each of the 10 bands.</summary>
    float[] CurrentBands { get; }

    /// <summary>Emits a new float[10] snapshot after any band change.</summary>
    IObservable<float[]> BandsChanged { get; }

    /// <summary>All available presets (built-in + any user-saved presets).</summary>
    IReadOnlyList<EqualizerPreset> Presets { get; }

    /// <summary>Sets the gain for one band (clamped to −12…+12 dB).</summary>
    Task SetBandAsync(int bandIndex, float dB);

    /// <summary>Applies a named preset, updating all 10 bands atomically.</summary>
    Task ApplyPresetAsync(string presetName);

    /// <summary>Enables or disables the equalizer entirely.</summary>
    Task SetEnabledAsync(bool enabled);

    /// <summary>Resets all bands to 0 dB without changing the enabled state.</summary>
    Task ResetAsync();
}
