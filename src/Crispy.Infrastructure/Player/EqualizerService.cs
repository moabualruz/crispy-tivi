using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// IEqualizerService implementation.
///
/// Desktop/Mobile: delegates to GStreamer via <see cref="GstreamerPlayerService.ApplyEqualizerBands"/>.
/// Browser: no-op stub (Web Audio API EQ handled via equalizer.js injected in Crispy.Browser).
/// If GStreamer is not available at runtime, behaves as an in-memory stub.
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

        if (_isEnabled)
        {
            PushBandsToPlayer();
        }

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

        if (_isEnabled)
        {
            PushBandsToPlayer();
        }

        EmitBandsChanged();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task SetEnabledAsync(bool enabled)
    {
        _isEnabled = enabled;

        if (enabled)
        {
            PushBandsToPlayer();
        }
        else
        {
            ClearPlayerEqualizer();
        }

        _logger.LogDebug("Equalizer {State}", enabled ? "enabled" : "disabled");
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task ResetAsync()
    {
        _currentBands = new float[10];

        if (_isEnabled)
        {
            PushBandsToPlayer();
        }

        EmitBandsChanged();
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public void Dispose() => _bandsChanged.Dispose();

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private void EmitBandsChanged() => _bandsChanged.OnNext((float[])_currentBands.Clone());

    /// <summary>
    /// Passes the current band values to the player service's equalizer.
    /// GstreamerPlayerService owns the GStreamer equalizer-10bands element so that
    /// EqualizerService has no direct reference to GStreamer types and compiles
    /// (and tests) cleanly without native GStreamer present.
    /// </summary>
    private void PushBandsToPlayer()
    {
        if (_playerService is GstreamerPlayerService gst)
        {
            gst.ApplyEqualizerBands(_currentBands);
        }
    }

    private void ClearPlayerEqualizer()
    {
        if (_playerService is GstreamerPlayerService gst)
        {
            gst.ClearEqualizer();
        }
    }
}
