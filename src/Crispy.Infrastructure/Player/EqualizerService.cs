using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using Microsoft.Extensions.Logging;

#if LIBVLC
using LibVLCSharp.Shared;
#endif

namespace Crispy.Infrastructure.Player;

/// <summary>
/// IEqualizerService implementation.
///
/// Desktop/Mobile: delegates to LibVLC AudioEqualizer API.
/// Browser: no-op stub (Web Audio API EQ handled via equalizer.js injected in Crispy.Browser).
/// When LIBVLC is not defined (packages not yet restored), behaves as an in-memory stub.
///
/// Satisfies PLR-33 (10-band EQ overlay with preset management).
/// </summary>
public sealed class EqualizerService : IEqualizerService, IDisposable
{
    private readonly IPlayerService _playerService;
    private readonly ILogger<EqualizerService> _logger;

    private bool _isEnabled;
    private float[] _currentBands = new float[10];
    private readonly SimpleSubject<float[]> _bandsChanged = new();

#if LIBVLC
#pragma warning disable CS0169, CS0414, CS0649
    private AudioEqualizer? _equalizer;
#pragma warning restore CS0169, CS0414, CS0649
#endif

    public EqualizerService(IPlayerService playerService, ILogger<EqualizerService> logger)
    {
        _playerService = playerService;
        _logger = logger;
    }

    /// <inheritdoc />
    public bool IsEnabled => _isEnabled;

    /// <inheritdoc />
    public float[] CurrentBands => (float[])_currentBands.Clone();

    /// <inheritdoc />
    public IObservable<float[]> BandsChanged => _bandsChanged;

    /// <inheritdoc />
    public IReadOnlyList<EqualizerPreset> Presets => EqualizerPreset.BuiltIn;

    /// <inheritdoc />
    public Task SetBandAsync(int bandIndex, float dB)
    {
        if (bandIndex is < 0 or > 9)
        {
            throw new ArgumentOutOfRangeException(nameof(bandIndex), "Band index must be 0–9.");
        }

        var clamped = Math.Clamp(dB, -12f, 12f);
        _currentBands[bandIndex] = clamped;

#if LIBVLC
        ApplyToVlc();
#endif

        EmitBandsChanged();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task ApplyPresetAsync(string presetName)
    {
        var preset = EqualizerPreset.BuiltIn.FirstOrDefault(
            p => string.Equals(p.Name, presetName, StringComparison.OrdinalIgnoreCase));

        if (preset is null)
        {
            _logger.LogWarning("ApplyPresetAsync: preset '{Name}' not found", presetName);
            return Task.CompletedTask;
        }

        _currentBands = (float[])preset.Bands.Clone();

#if LIBVLC
        ApplyToVlc();
#endif

        EmitBandsChanged();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetEnabledAsync(bool enabled)
    {
        _isEnabled = enabled;

#if LIBVLC
        if (enabled)
        {
            ApplyToVlc();
        }
        else
        {
            DisableVlcEqualizer();
        }
#endif

        _logger.LogDebug("Equalizer {State}", enabled ? "enabled" : "disabled");
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task ResetAsync()
    {
        _currentBands = new float[10];

#if LIBVLC
        if (_isEnabled)
        {
            ApplyToVlc();
        }
#endif

        EmitBandsChanged();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public void Dispose() => _bandsChanged.Dispose();

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private void EmitBandsChanged() => _bandsChanged.OnNext((float[])_currentBands.Clone());

#if LIBVLC
    private void ApplyToVlc()
    {
        if (_playerService is not VlcPlayerService vlc)
        {
            return;
        }

        _equalizer ??= new AudioEqualizer();

        for (var i = 0; i < 10; i++)
        {
            _equalizer.SetAmp(_currentBands[i], (uint)i);
        }

        vlc.SetEqualizer(_equalizer);
    }

    private void DisableVlcEqualizer()
    {
        if (_playerService is VlcPlayerService vlc)
        {
            vlc.SetEqualizer(null);
        }

        _equalizer?.Dispose();
        _equalizer = null;
    }
#endif
}
