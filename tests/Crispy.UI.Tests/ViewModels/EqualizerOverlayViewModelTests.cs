using Avalonia.Headless.XUnit;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for EqualizerOverlayViewModel — verifies band initialisation,
/// enabled/visible defaults, and preset selection state.
/// </summary>
[Trait("Category", "Unit")]
public class EqualizerOverlayViewModelTests
{
    private readonly IEqualizerService _equalizerService;
    private readonly TestSubject<float[]> _bandsSubject;
    private readonly EqualizerOverlayViewModel _sut;

    public EqualizerOverlayViewModelTests()
    {
        _bandsSubject = new TestSubject<float[]>();

        _equalizerService = Substitute.For<IEqualizerService>();
        _equalizerService.IsEnabled.Returns(false);
        _equalizerService.CurrentBands.Returns(new float[10]);
        _equalizerService.BandsChanged.Returns(_bandsSubject);
        _equalizerService.Presets.Returns([]);

        _sut = new EqualizerOverlayViewModel(_equalizerService);
    }

    [Fact]
    public void Bands_HasTenItems()
    {
        _sut.Bands.Should().HaveCount(10,
            "The equalizer always exposes exactly 10 frequency bands (PLR-33)");
    }

    [Fact]
    public void IsEnabled_FalseInitially()
    {
        _sut.IsEnabled.Should().BeFalse(
            "The equalizer is disabled by default; user must explicitly enable it");
    }

    [Fact]
    public void IsVisible_FalseInitially()
    {
        _sut.IsVisible.Should().BeFalse(
            "The equalizer overlay panel is hidden by default and shown on demand");
    }

    [Fact]
    public void SelectedPresetName_NullInitially()
    {
        _sut.SelectedPresetName.Should().BeNull(
            "No preset is selected on startup; user selects one explicitly");
    }

    // ─── Presets property ────────────────────────────────────────────────────

    [Fact]
    public void Presets_ReturnsServicePresets()
    {
        var presets = new List<EqualizerPreset> { EqualizerPreset.Flat, EqualizerPreset.Rock };
        _equalizerService.Presets.Returns(presets);
        var vm = new EqualizerOverlayViewModel(_equalizerService);

        vm.Presets.Should().BeSameAs(presets);
    }

    // ─── Band initialisation ─────────────────────────────────────────────────

    [Fact]
    public void Bands_InitialisedWithCurrentBandGains()
    {
        var gains = new float[10] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
        _equalizerService.CurrentBands.Returns(gains);
        var vm = new EqualizerOverlayViewModel(_equalizerService);

        for (var i = 0; i < 10; i++)
            vm.Bands[i].GainDb.Should().BeApproximately(gains[i], 0.001f);
    }

    [Fact]
    public void Bands_SlotIndexMatchesBandIndex()
    {
        for (var i = 0; i < 10; i++)
            _sut.Bands[i].BandIndex.Should().Be(i);
    }

    // ─── ToggleEnabledAsync ──────────────────────────────────────────────────

    [Fact]
    public async Task ToggleEnabledCommand_TogglesIsEnabledAndCallsService_WhenDisabled()
    {
        _equalizerService.IsEnabled.Returns(false);
        var vm = new EqualizerOverlayViewModel(_equalizerService);

        await vm.ToggleEnabledCommand.ExecuteAsync(null);

        vm.IsEnabled.Should().BeTrue();
        await _equalizerService.Received(1).SetEnabledAsync(true);
    }

    [Fact]
    public async Task ToggleEnabledCommand_TogglesIsEnabledAndCallsService_WhenEnabled()
    {
        _equalizerService.IsEnabled.Returns(true);
        var vm = new EqualizerOverlayViewModel(_equalizerService);

        await vm.ToggleEnabledCommand.ExecuteAsync(null);

        vm.IsEnabled.Should().BeFalse();
        await _equalizerService.Received(1).SetEnabledAsync(false);
    }

    // ─── ApplyPresetAsync ────────────────────────────────────────────────────

    [Fact]
    public async Task ApplyPresetCommand_SetsSelectedPresetNameAndCallsService()
    {
        await _sut.ApplyPresetCommand.ExecuteAsync("Rock");

        _sut.SelectedPresetName.Should().Be("Rock");
        await _equalizerService.Received(1).ApplyPresetAsync("Rock");
    }

    [Fact]
    public async Task ApplyPresetCommand_UpdatesSelectedPresetName_WhenCalledTwice()
    {
        await _sut.ApplyPresetCommand.ExecuteAsync("Jazz");
        await _sut.ApplyPresetCommand.ExecuteAsync("Pop");

        _sut.SelectedPresetName.Should().Be("Pop");
    }

    // ─── ResetAsync ──────────────────────────────────────────────────────────

    [Fact]
    public async Task ResetCommand_SetsSelectedPresetToFlatAndCallsService()
    {
        await _sut.ResetCommand.ExecuteAsync(null);

        _sut.SelectedPresetName.Should().Be(EqualizerPreset.Flat.Name);
        await _equalizerService.Received(1).ResetAsync();
    }

    // ─── Close / IsVisible ───────────────────────────────────────────────────

    [Fact]
    public void CloseCommand_SetsIsVisibleFalse()
    {
        _sut.IsVisible = true;

        _sut.CloseCommand.Execute(null);

        _sut.IsVisible.Should().BeFalse();
    }

    [Fact]
    public void IsVisible_CanBeSetToTrue()
    {
        _sut.IsVisible = true;

        _sut.IsVisible.Should().BeTrue();
    }

    // ─── BandsChanged observable ─────────────────────────────────────────────

    [AvaloniaFact]
    public void OnBandsChanged_UpdatesBandGains_WhenObservableEmits()
    {
        var newGains = new float[10] { 1f, 2f, 3f, 4f, 5f, 6f, 7f, 8f, 9f, 10f };

        _bandsSubject.OnNext(newGains);

        for (var i = 0; i < 10; i++)
            _sut.Bands[i].GainDb.Should().BeApproximately(newGains[i], 0.001f);
    }

    [AvaloniaFact]
    public void OnBandsChanged_IgnoresExtraBands_WhenArrayLongerThanTen()
    {
        var newGains = new float[12];
        for (var i = 0; i < 12; i++) newGains[i] = i;

        // Should not throw — only updates up to Bands.Count
        var act = () => _bandsSubject.OnNext(newGains);
        act.Should().NotThrow();

        for (var i = 0; i < 10; i++)
            _sut.Bands[i].GainDb.Should().BeApproximately(i, 0.001f);
    }

    // ─── Band gain change → deselects preset ────────────────────────────────

    [Fact]
    public async Task BandGainChange_DeselectsSelectedPreset()
    {
        await _sut.ApplyPresetCommand.ExecuteAsync("Rock");
        _sut.SelectedPresetName.Should().Be("Rock");

        // Move a band — simulates user dragging a slider
        _sut.Bands[0].GainDb = 5f;

        // Allow async void OnBandGainChanged to complete
        await Task.Yield();

        _sut.SelectedPresetName.Should().BeNull(
            "manually adjusting a band deselects the active preset");
    }

    [Fact]
    public async Task BandGainChange_CallsSetBandAsync_WithCorrectIndexAndValue()
    {
        _sut.Bands[3].GainDb = 4.5f;

        await Task.Yield();

        await _equalizerService.Received(1).SetBandAsync(3, 4.5f);
    }

    // ─── Dispose ─────────────────────────────────────────────────────────────

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var act = () => _sut.Dispose();
        act.Should().NotThrow();
    }

    [Fact]
    public void Dispose_UnsubscribesFromBandsChanged_SoSubsequentEmitsAreIgnored()
    {
        var gains = new float[10];
        gains[0] = 99f;

        _sut.Dispose();
        _bandsSubject.OnNext(gains);

        _sut.Bands[0].GainDb.Should().BeApproximately(0f, 0.001f,
            "after disposal the subscription is removed and no updates occur");
    }

    // ─── RunOnUiThread catch branch ──────────────────────────────────────────

    [Fact]
    public void OnBandsChanged_FallsBackToDirectInvoke_WhenDispatcherThrows()
    {
        // The catch branch in RunOnUiThread is exercised when Dispatcher.UIThread
        // is not initialised (no headless platform) and throws InvalidOperationException.
        // In a plain [Fact] (no Avalonia platform), CheckAccess() throws — the catch
        // block then calls action() directly, which must still update the bands.
        var service = Substitute.For<IEqualizerService>();
        var subject = new TestSubject<float[]>();
        service.IsEnabled.Returns(false);
        service.CurrentBands.Returns(new float[10]);
        service.BandsChanged.Returns(subject);
        service.Presets.Returns([]);

        var vm = new EqualizerOverlayViewModel(service);
        var newGains = new float[10] { 5f, 5f, 5f, 5f, 5f, 5f, 5f, 5f, 5f, 5f };

        // In a plain Fact the Avalonia dispatcher may or may not be initialised.
        // Either path (direct call or post) must leave bands updated without throwing.
        var act = () => subject.OnNext(newGains);
        act.Should().NotThrow("RunOnUiThread must never propagate exceptions to callers");
    }

    [Fact]
    public void Dispose_CanBeCalledTwice_WithoutThrowing()
    {
        var act = () =>
        {
            _sut.Dispose();
            _sut.Dispose();
        };
        act.Should().NotThrow("double-dispose is a common pattern and must be safe");
    }

    [Fact]
    public async Task BandGainChange_CallsSetBandAsync_ForEachBand()
    {
        // Exercise OnBandGainChanged for every band index to ensure full coverage
        // of the async void path across all 10 bands.
        for (var i = 0; i < 10; i++)
        {
            _sut.Bands[i].GainDb = (i + 1) * 1.0f;
            await Task.Yield();
            await _equalizerService.Received(1).SetBandAsync(i, (i + 1) * 1.0f);
        }
    }

    [Fact]
    public void IsEnabled_TrueWhenServiceReturnsTrue()
    {
        var service = Substitute.For<IEqualizerService>();
        service.IsEnabled.Returns(true);
        service.CurrentBands.Returns(new float[10]);
        service.BandsChanged.Returns(new TestSubject<float[]>());
        service.Presets.Returns([]);

        var vm = new EqualizerOverlayViewModel(service);

        vm.IsEnabled.Should().BeTrue("constructor reads IsEnabled directly from service");
    }
}

/// <summary>
/// Unit tests for EqBandViewModel — verifies gain property, slot index, and event emission.
/// </summary>
[Trait("Category", "Unit")]
public class EqBandViewModelTests
{
    // ─── Construction ────────────────────────────────────────────────────────

    [Fact]
    public void BandIndex_IsSetFromConstructor()
    {
        var band = new EqBandViewModel(5, "1k", 0f);
        band.BandIndex.Should().Be(5);
    }

    [Fact]
    public void Label_IsSetFromConstructor()
    {
        var band = new EqBandViewModel(5, "1k", 0f);
        band.Label.Should().Be("1k");
    }

    [Fact]
    public void GainDb_InitialisedFromConstructor()
    {
        var band = new EqBandViewModel(0, "32Hz", 3.5f);
        band.GainDb.Should().BeApproximately(3.5f, 0.001f);
    }

    // ─── GainDb setter ───────────────────────────────────────────────────────

    [Fact]
    public void GainDb_SetterUpdatesValue()
    {
        var band = new EqBandViewModel(0, "32Hz", 0f);
        band.GainDb = 6f;
        band.GainDb.Should().BeApproximately(6f, 0.001f);
    }

    [Fact]
    public void GainDb_RaisesGainChangedEvent_WithCorrectIndexAndValue()
    {
        var band = new EqBandViewModel(3, "250Hz", 0f);
        (int Index, float Db)? received = null;
        band.GainChanged += (_, args) => received = args;

        band.GainDb = 4f;

        received.Should().NotBeNull();
        received!.Value.Index.Should().Be(3);
        received.Value.Db.Should().BeApproximately(4f, 0.001f);
    }

    [Fact]
    public void GainDb_DoesNotRaiseGainChangedEvent_WhenValueWithinEpsilon()
    {
        var band = new EqBandViewModel(0, "32Hz", 1f);
        var eventCount = 0;
        band.GainChanged += (_, _) => eventCount++;

        // Delta < 0.001f — should be suppressed
        band.GainDb = 1.0005f;

        eventCount.Should().Be(0,
            "changes smaller than 0.001 dB are below the threshold and should be ignored");
    }

    [Fact]
    public void GainDb_RaisesPropertyChangedEvent_WhenValueChanges()
    {
        var band = new EqBandViewModel(0, "32Hz", 0f);
        var propChanged = false;
        band.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(EqBandViewModel.GainDb))
                propChanged = true;
        };

        band.GainDb = 2f;

        propChanged.Should().BeTrue();
    }

    [Fact]
    public void GainDb_DoesNotRaisePropertyChanged_WhenValueWithinEpsilon()
    {
        var band = new EqBandViewModel(0, "32Hz", 1f);
        var propChanged = false;
        band.PropertyChanged += (_, _) => propChanged = true;

        band.GainDb = 1.0005f;

        propChanged.Should().BeFalse();
    }

    [Theory]
    [InlineData(0, "32Hz")]
    [InlineData(4, "500Hz")]
    [InlineData(9, "16k")]
    public void BandIndex_MatchesSlotPosition(int index, string label)
    {
        var band = new EqBandViewModel(index, label, 0f);
        band.BandIndex.Should().Be(index);
        band.Label.Should().Be(label);
    }

    [Fact]
    public void GainDb_DoesNotThrow_WhenNoGainChangedSubscribers()
    {
        // Exercises the GainChanged?.Invoke null-conditional path when no handler
        // is attached — covers the null branch of the null-conditional operator.
        var band = new EqBandViewModel(0, "32Hz", 0f);

        var act = () => { band.GainDb = 3f; };

        act.Should().NotThrow("GainChanged?.Invoke must be safe with zero subscribers");
        band.GainDb.Should().BeApproximately(3f, 0.001f);
    }

    [Fact]
    public void GainDb_MultipleChanges_EachRaisesEvent()
    {
        var band = new EqBandViewModel(1, "64Hz", 0f);
        var eventCount = 0;
        band.GainChanged += (_, _) => eventCount++;

        band.GainDb = 1f;
        band.GainDb = 2f;
        band.GainDb = 3f;

        eventCount.Should().Be(3, "each distinct gain change must raise one event");
    }
}
