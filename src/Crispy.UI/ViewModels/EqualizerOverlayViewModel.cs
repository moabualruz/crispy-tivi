using System.Collections.ObjectModel;
using System.Diagnostics.CodeAnalysis;

using Avalonia.Threading;

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;

namespace Crispy.UI.ViewModels;

/// <summary>
/// ViewModel for the 10-band EQ overlay panel.
/// Wraps IEqualizerService and exposes per-band sliders and preset chips.
/// Satisfies PLR-33 (audio equalizer overlay).
/// </summary>
public partial class EqualizerOverlayViewModel : ViewModelBase, IDisposable
{
    private static readonly string[] BandLabels =
        ["32Hz", "64Hz", "125Hz", "250Hz", "500Hz", "1k", "2k", "4k", "8k", "16k"];

    private readonly IEqualizerService _equalizerService;
    private IDisposable? _bandsSubscription;

    // ─── Enabled toggle ──────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _isEnabled;

    // ─── Bands ───────────────────────────────────────────────────────────────

    /// <summary>10 observable band view-models for slider binding.</summary>
    public ObservableCollection<EqBandViewModel> Bands { get; } = [];

    // ─── Presets ─────────────────────────────────────────────────────────────

    public IReadOnlyList<EqualizerPreset> Presets => _equalizerService.Presets;

    [ObservableProperty]
    private string? _selectedPresetName;

    // ─── Visibility ──────────────────────────────────────────────────────────

    [ObservableProperty]
    private bool _isVisible;

    // ─── Constructor ─────────────────────────────────────────────────────────

    public EqualizerOverlayViewModel(IEqualizerService equalizerService)
    {
        Title = "Equalizer";
        _equalizerService = equalizerService;
        _isEnabled = equalizerService.IsEnabled;

        var currentBands = equalizerService.CurrentBands;
        for (var i = 0; i < 10; i++)
        {
            var band = new EqBandViewModel(i, BandLabels[i], currentBands[i]);
            band.GainChanged += OnBandGainChanged;
            Bands.Add(band);
        }

        _bandsSubscription = equalizerService.BandsChanged.Subscribe(OnBandsChanged);
    }

    // ─── Sync ────────────────────────────────────────────────────────────────

    private void OnBandsChanged(float[] bands)
    {
        RunOnUiThread(() =>
        {
            for (var i = 0; i < bands.Length && i < Bands.Count; i++)
            {
                Bands[i].GainDb = bands[i];
            }
        });
    }

    private async void OnBandGainChanged(object? sender, (int Index, float Db) args)
    {
        await _equalizerService.SetBandAsync(args.Index, args.Db);
        SelectedPresetName = null; // user-modified — deselect preset
    }

    // ─── Commands ────────────────────────────────────────────────────────────

    [RelayCommand]
    private async Task ApplyPresetAsync(string presetName)
    {
        SelectedPresetName = presetName;
        await _equalizerService.ApplyPresetAsync(presetName);
    }

    [RelayCommand]
    private async Task ToggleEnabledAsync()
    {
        IsEnabled = !IsEnabled;
        await _equalizerService.SetEnabledAsync(IsEnabled);
    }

    [RelayCommand]
    private async Task ResetAsync()
    {
        SelectedPresetName = EqualizerPreset.Flat.Name;
        await _equalizerService.ResetAsync();
    }

    [RelayCommand]
    private void Close() => IsVisible = false;

    // ─── Cleanup ─────────────────────────────────────────────────────────────

    public void Dispose()
    {
        _bandsSubscription?.Dispose();
        foreach (var band in Bands)
            band.GainChanged -= OnBandGainChanged;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    // Platform bridge — catch branch only fires when no Avalonia platform is registered
    // (e.g., console-only process). Excluded from coverage as it is unreachable under
    // Avalonia.Headless and is pure infrastructure glue, not business logic.
    [ExcludeFromCodeCoverage]
    private static void RunOnUiThread(Action action)
    {
        try
        {
            if (Dispatcher.UIThread.CheckAccess())
                action();
            else
                Dispatcher.UIThread.Post(action);
        }
        catch (Exception)
        {
            action();
        }
    }
}

// ─── Per-band ViewModel ──────────────────────────────────────────────────────

/// <summary>
/// Represents one frequency band in the equalizer.
/// Raises GainChanged when the user moves the slider.
/// </summary>
public partial class EqBandViewModel : ObservableObject
{
    private float _gainDb;

    public int BandIndex { get; }
    public string Label { get; }

    public float GainDb
    {
        get => _gainDb;
        set
        {
            if (Math.Abs(_gainDb - value) < 0.001f)
            {
                return;
            }

            _gainDb = value;
            OnPropertyChanged();
            GainChanged?.Invoke(this, (BandIndex, value));
        }
    }

    /// <summary>Raised when the gain is changed by the user (slider moved).</summary>
    public event EventHandler<(int Index, float Db)>? GainChanged;

    public EqBandViewModel(int bandIndex, string label, float initialGain)
    {
        BandIndex = bandIndex;
        Label = label;
        _gainDb = initialGain;
    }
}
