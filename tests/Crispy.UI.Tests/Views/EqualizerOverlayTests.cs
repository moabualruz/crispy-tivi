using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// EqualizerOverlay uses a ToggleSwitch whose Fluent theme template (PART_MovingKnobs)
/// is not available in the headless test platform, causing a KeyNotFoundException during
/// layout. The control itself is smoke-tested via the PlayerView headless test (which
/// embeds it). This file tests EqualizerOverlayViewModel state in isolation instead.
/// </summary>
[Trait("Category", "UI")]
public class EqualizerOverlayTests
{
    private static EqualizerOverlayViewModel BuildVm()
    {
        var bandsSubject = new TestSubject<float[]>();

        var equalizerService = Substitute.For<IEqualizerService>();
        equalizerService.IsEnabled.Returns(false);
        equalizerService.CurrentBands.Returns(new float[10]);
        equalizerService.BandsChanged.Returns(bandsSubject);
        equalizerService.Presets.Returns(EqualizerPreset.BuiltIn);

        return new EqualizerOverlayViewModel(equalizerService);
    }

    [Fact]
    public void EqualizerOverlayViewModel_InitialState_HasTenBands()
    {
        var vm = BuildVm();

        vm.Bands.Should().HaveCount(10, "equalizer must expose exactly 10 frequency bands");
    }

    [Fact]
    public void EqualizerOverlayViewModel_InitialState_IsDisabledAndHidden()
    {
        var vm = BuildVm();

        vm.IsEnabled.Should().BeFalse("equalizer starts disabled");
        vm.IsVisible.Should().BeFalse("overlay starts hidden");
    }

    [Fact]
    public void EqualizerOverlayViewModel_InitialState_AllBandsAtZero()
    {
        var vm = BuildVm();

        vm.Bands.Should().OnlyContain(b => Math.Abs(b.GainDb) < 0.001f,
            "all bands should be 0 dB when CurrentBands returns float[10] zeros");
    }

    [Fact]
    public void EqualizerOverlayViewModel_Presets_MatchBuiltIn()
    {
        var vm = BuildVm();

        vm.Presets.Should().BeEquivalentTo(EqualizerPreset.BuiltIn,
            "Presets must be forwarded from IEqualizerService");
    }
}
